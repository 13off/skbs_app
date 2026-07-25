import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';

const EMPTY_DB = {
  version: 2,
  admins: [],
  sessions: {},
  applications: [],
};

export class JsonStore {
  constructor(filePath) {
    this.filePath = path.resolve(filePath || './data/bot-data.json');
    this.db = structuredClone(EMPTY_DB);
    this.writeQueue = Promise.resolve();
  }

  async init() {
    await mkdir(path.dirname(this.filePath), { recursive: true });
    try {
      const parsed = JSON.parse(await readFile(this.filePath, 'utf8'));
      this.db = {
        ...structuredClone(EMPTY_DB),
        ...parsed,
        version: 2,
        admins: Array.isArray(parsed.admins) ? parsed.admins : [],
        sessions: parsed.sessions && typeof parsed.sessions === 'object' ? parsed.sessions : {},
        applications: Array.isArray(parsed.applications) ? parsed.applications : [],
      };
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      await this.persist();
    }
  }

  persist() {
    this.writeQueue = this.writeQueue.then(async () => {
      const temporary = `${this.filePath}.tmp`;
      await writeFile(temporary, JSON.stringify(this.db, null, 2), 'utf8');
      await rename(temporary, this.filePath);
    });
    return this.writeQueue;
  }

  getSession(userId) {
    return this.db.sessions[String(userId)] ?? null;
  }

  async setSession(userId, session) {
    this.db.sessions[String(userId)] = {
      ...session,
      updatedAt: new Date().toISOString(),
    };
    await this.persist();
    return this.db.sessions[String(userId)];
  }

  async resetSession(userId) {
    delete this.db.sessions[String(userId)];
    await this.persist();
  }

  isAdmin(userId) {
    return this.db.admins.some((admin) => admin.userId === String(userId));
  }

  getAdmins() {
    return [...this.db.admins];
  }

  async registerAdmin(user) {
    const userId = String(user.user_id);
    const existing = this.db.admins.find((admin) => admin.userId === userId);
    if (existing) return existing;

    const admin = {
      userId,
      firstName: user.first_name ?? '',
      lastName: user.last_name ?? '',
      username: user.username ?? null,
      registeredAt: new Date().toISOString(),
    };
    this.db.admins.push(admin);
    await this.persist();
    return admin;
  }

  async addApplication(application) {
    const record = {
      id: `MAX-${Date.now()}-${Math.random().toString(36).slice(2, 7).toUpperCase()}`,
      status: 'new',
      syncStatus: 'pending',
      syncAttempts: 0,
      createdAt: new Date().toISOString(),
      ...application,
    };
    this.db.applications.push(record);
    await this.persist();
    return record;
  }

  getApplication(id) {
    return this.db.applications.find((item) => item.id === id) ?? null;
  }

  async updateApplication(id, values) {
    const index = this.db.applications.findIndex((item) => item.id === id);
    if (index < 0) return null;
    this.db.applications[index] = {
      ...this.db.applications[index],
      ...values,
      updatedAt: new Date().toISOString(),
    };
    await this.persist();
    return this.db.applications[index];
  }

  getPendingApplications(limit = 50) {
    return this.db.applications
      .filter((item) => item.syncStatus !== 'synced')
      .slice(-limit);
  }

  getRecentApplications(limit = 10) {
    return this.db.applications.slice(-limit).reverse();
  }

  getLatestSyncedApplicationByUserId(userId) {
    const cleanUserId = String(userId);
    return [...this.db.applications]
      .reverse()
      .find((item) => item.maxUserId === cleanUserId && item.syncStatus === 'synced') ?? null;
  }
}

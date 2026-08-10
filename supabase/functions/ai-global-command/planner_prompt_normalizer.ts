import { clean } from "./shared.ts";

// This normalizer is intentionally tiny and deterministic. It only repairs
// Russian surface forms that otherwise collide with planner action markers.
// It never resolves people, objects or entity IDs.
export function normalizePlannerPrompt(value: unknown): string {
  return clean(value, 4000)
    // «первым трём» must reach the existing count lexeme «троим» after the
    // application's global ё→е normalization.
    .replace(/(^|[^а-яё])тр[её]м(?=$|[^а-яё])/gi, "$1троим")
    // Passive descriptions belong to the selector, not the action clause.
    // Convert them to the already-supported neutral filter so the root
    // «назнач» cannot be mistaken for an imperative action marker.
    .replace(
      /(?:не\s+назначен[а-яё]*\s+ответствен[а-яё]*|ответствен[а-яё]*\s+не\s+назначен[а-яё]*)/gi,
      "без ответственного",
    )
    .replace(/\s+/g, " ")
    .trim();
}

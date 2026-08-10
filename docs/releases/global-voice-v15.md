# AppСтрой Global Voice v15

Крупный релиз: детерминированный tool planner поверх production-данных.

Одна реплика может совместить поиск по нескольким таблицам, фильтрацию, выбор части результата и подготовку штатных действий. Старые single-intent и reference routers сохранены; v15 работает отдельным слоем между action-trace v14 и reference routers v13/v12.

Writes не выполняются Edge-планировщиком. Он формирует существующие action payloads; клиентские coordinators сохраняют подтверждение, role validation и AI audit.

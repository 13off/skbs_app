-- Device-token mutations are handled by the JWT-protected manage-push-device
-- Edge Function. No authenticated SECURITY DEFINER RPC remains exposed.

drop function if exists public.register_current_push_device(text, text, text, boolean);
drop function if exists public.set_current_push_device_enabled(text, boolean);
drop function if exists public.unregister_current_push_device(text);

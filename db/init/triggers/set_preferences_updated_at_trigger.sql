-- db/init/triggers/set_preferences_updated_at_trigger.sql
/*
Triggers to automatically update updated_at timestamp for all user preference
tables
*/

CREATE TRIGGER trigger_update_user_notification_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_notification_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_display_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_display_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_privacy_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_privacy_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_accessibility_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_accessibility_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_language_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_language_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_security_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_security_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_social_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_social_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_sound_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_sound_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trigger_update_user_theme_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_theme_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

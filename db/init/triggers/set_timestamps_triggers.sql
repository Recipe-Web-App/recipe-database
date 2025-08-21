-- db/init/triggers/set_timestamps_triggers.sql
-- Centralized creation of created_at and updated_at triggers

-- Helper: drop existing triggers if present and recreate them for all tables

-- Users
DROP TRIGGER IF EXISTS trigger_set_users_created_at ON recipe_manager.users;
CREATE TRIGGER trigger_set_users_created_at
BEFORE INSERT ON recipe_manager.users
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

DROP TRIGGER IF EXISTS trigger_update_users_updated_at ON recipe_manager.users;
CREATE TRIGGER trigger_update_users_updated_at
BEFORE UPDATE ON recipe_manager.users
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_notifications_created_at
ON recipe_manager.notifications;
CREATE TRIGGER trigger_set_notifications_created_at
BEFORE INSERT ON recipe_manager.notifications
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_notifications_updated_at
ON recipe_manager.notifications;
CREATE TRIGGER trigger_update_notifications_updated_at
BEFORE UPDATE ON recipe_manager.notifications
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- Ingredients
DROP TRIGGER IF EXISTS trigger_set_ingredients_created_at
ON recipe_manager.ingredients;
CREATE TRIGGER trigger_set_ingredients_created_at
BEFORE INSERT ON recipe_manager.ingredients
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_ingredients_updated_at
ON recipe_manager.ingredients;
CREATE TRIGGER trigger_update_ingredients_updated_at
BEFORE UPDATE ON recipe_manager.ingredients
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- Recipes
DROP TRIGGER IF EXISTS trigger_set_recipes_created_at ON recipe_manager.recipes;
CREATE TRIGGER trigger_set_recipes_created_at
BEFORE INSERT ON recipe_manager.recipes
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

DROP TRIGGER IF EXISTS trigger_update_recipes_updated_at
ON recipe_manager.recipes;
CREATE TRIGGER trigger_update_recipes_updated_at
BEFORE UPDATE ON recipe_manager.recipes
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- Recipe steps (created_at only)
DROP TRIGGER IF EXISTS trigger_set_recipe_steps_created_at
ON recipe_manager.recipe_steps;
CREATE TRIGGER trigger_set_recipe_steps_created_at
BEFORE INSERT ON recipe_manager.recipe_steps
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

-- Recipe revisions (created_at only)
DROP TRIGGER IF EXISTS trigger_set_recipe_revisions_created_at
ON recipe_manager.recipe_revisions;
CREATE TRIGGER trigger_set_recipe_revisions_created_at
BEFORE INSERT ON recipe_manager.recipe_revisions
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

-- Reviews (created_at only)
DROP TRIGGER IF EXISTS trigger_set_reviews_created_at ON recipe_manager.reviews;
CREATE TRIGGER trigger_set_reviews_created_at
BEFORE INSERT ON recipe_manager.reviews
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

-- Meal plans
DROP TRIGGER IF EXISTS trigger_set_meal_plans_created_at
ON recipe_manager.meal_plans;
CREATE TRIGGER trigger_set_meal_plans_created_at
BEFORE INSERT ON recipe_manager.meal_plans
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_meal_plans_updated_at
ON recipe_manager.meal_plans;
CREATE TRIGGER trigger_update_meal_plans_updated_at
BEFORE UPDATE ON recipe_manager.meal_plans
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- Nutritional info
DROP TRIGGER IF EXISTS trigger_set_nutritional_info_created_at
ON recipe_manager.nutritional_info;
CREATE TRIGGER trigger_set_nutritional_info_created_at
BEFORE INSERT ON recipe_manager.nutritional_info
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_nutritional_info_updated_at
ON recipe_manager.nutritional_info;
CREATE TRIGGER trigger_update_nutritional_info_updated_at
BEFORE UPDATE ON recipe_manager.nutritional_info
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- Ingredient comments
DROP TRIGGER IF EXISTS trigger_set_ingredient_comments_created_at
ON recipe_manager.ingredient_comments;
CREATE TRIGGER trigger_set_ingredient_comments_created_at
BEFORE INSERT ON recipe_manager.ingredient_comments
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_ingredient_comments_updated_at
ON recipe_manager.ingredient_comments;
CREATE TRIGGER trigger_update_ingredient_comments_updated_at
BEFORE UPDATE ON recipe_manager.ingredient_comments
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- User preference tables (created_at & updated_at)
DROP TRIGGER IF EXISTS trigger_set_user_notification_preferences_created_at
ON recipe_manager.user_notification_preferences;
CREATE TRIGGER trigger_set_user_notification_preferences_created_at
BEFORE INSERT ON recipe_manager.user_notification_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_notification_preferences_updated_at
ON recipe_manager.user_notification_preferences;
CREATE TRIGGER trigger_update_user_notification_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_notification_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_display_preferences_created_at
ON recipe_manager.user_display_preferences;
CREATE TRIGGER trigger_set_user_display_preferences_created_at
BEFORE INSERT ON recipe_manager.user_display_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_display_preferences_updated_at
ON recipe_manager.user_display_preferences;
CREATE TRIGGER trigger_update_user_display_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_display_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_privacy_preferences_created_at
ON recipe_manager.user_privacy_preferences;
CREATE TRIGGER trigger_set_user_privacy_preferences_created_at
BEFORE INSERT ON recipe_manager.user_privacy_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_privacy_preferences_updated_at
ON recipe_manager.user_privacy_preferences;
CREATE TRIGGER trigger_update_user_privacy_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_privacy_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_accessibility_preferences_created_at
ON recipe_manager.user_accessibility_preferences;
CREATE TRIGGER trigger_set_user_accessibility_preferences_created_at
BEFORE INSERT ON recipe_manager.user_accessibility_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_accessibility_preferences_updated_at
ON recipe_manager.user_accessibility_preferences;
CREATE TRIGGER trigger_update_user_accessibility_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_accessibility_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_language_preferences_created_at
ON recipe_manager.user_language_preferences;
CREATE TRIGGER trigger_set_user_language_preferences_created_at
BEFORE INSERT ON recipe_manager.user_language_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_language_preferences_updated_at
ON recipe_manager.user_language_preferences;
CREATE TRIGGER trigger_update_user_language_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_language_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_security_preferences_created_at
ON recipe_manager.user_security_preferences;
CREATE TRIGGER trigger_set_user_security_preferences_created_at
BEFORE INSERT ON recipe_manager.user_security_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_security_preferences_updated_at
ON recipe_manager.user_security_preferences;
CREATE TRIGGER trigger_update_user_security_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_security_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_sound_preferences_created_at
ON recipe_manager.user_sound_preferences;
CREATE TRIGGER trigger_set_user_sound_preferences_created_at
BEFORE INSERT ON recipe_manager.user_sound_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_sound_preferences_updated_at
ON recipe_manager.user_sound_preferences;
CREATE TRIGGER trigger_update_user_sound_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_sound_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_theme_preferences_created_at
ON recipe_manager.user_theme_preferences;
CREATE TRIGGER trigger_set_user_theme_preferences_created_at
BEFORE INSERT ON recipe_manager.user_theme_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_theme_preferences_updated_at
ON recipe_manager.user_theme_preferences;
CREATE TRIGGER trigger_update_user_theme_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_theme_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_user_social_preferences_created_at
ON recipe_manager.user_social_preferences;
CREATE TRIGGER trigger_set_user_social_preferences_created_at
BEFORE INSERT ON recipe_manager.user_social_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();
DROP TRIGGER IF EXISTS trigger_update_user_social_preferences_updated_at
ON recipe_manager.user_social_preferences;
CREATE TRIGGER trigger_update_user_social_preferences_updated_at
BEFORE UPDATE ON recipe_manager.user_social_preferences
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

-- Media and media relation tables
DROP TRIGGER IF EXISTS trigger_set_media_created_at
ON recipe_manager.media;
CREATE TRIGGER trigger_set_media_created_at
BEFORE INSERT ON recipe_manager.media
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

DROP TRIGGER IF EXISTS trigger_update_media_updated_at
ON recipe_manager.media;
CREATE TRIGGER trigger_update_media_updated_at
BEFORE UPDATE ON recipe_manager.media
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.update_timestamp();

DROP TRIGGER IF EXISTS trigger_set_recipe_media_created_at
ON recipe_manager.recipe_media;
CREATE TRIGGER trigger_set_recipe_media_created_at
BEFORE INSERT ON recipe_manager.recipe_media
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

DROP TRIGGER IF EXISTS trigger_set_ingredient_media_created_at
ON recipe_manager.ingredient_media;
CREATE TRIGGER trigger_set_ingredient_media_created_at
BEFORE INSERT ON recipe_manager.ingredient_media
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

DROP TRIGGER IF EXISTS trigger_set_step_media_created_at
ON recipe_manager.step_media;
CREATE TRIGGER trigger_set_step_media_created_at
BEFORE INSERT ON recipe_manager.step_media
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.set_created_at();

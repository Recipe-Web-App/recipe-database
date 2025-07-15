-- db/init/triggers/create_default_preferences_trigger.sql

-- Function to create default preferences for a new user
CREATE OR REPLACE FUNCTION recipe_manager.create_default_preferences()
RETURNS TRIGGER AS $$
BEGIN
    -- Notification preferences
    INSERT INTO recipe_manager.user_notification_preferences (
        user_id,
        email_notifications,
        push_notifications,
        sms_notifications,
        marketing_emails,
        security_alerts,
        activity_summaries,
        recipe_recommendations,
        social_interactions
    ) VALUES (
        NEW.user_id,
        TRUE,
        TRUE,
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        TRUE,
        TRUE
    );

    -- Display preferences
    INSERT INTO recipe_manager.user_display_preferences (
        user_id,
        font_size,
        color_scheme,
        layout_density,
        show_images,
        compact_mode
    ) VALUES (
        NEW.user_id,
        'MEDIUM'::recipe_manager.font_size_enum,
        'LIGHT'::recipe_manager.color_scheme_enum,
        'COMFORTABLE'::recipe_manager.layout_density_enum,
        TRUE,
        FALSE
    );

    -- Privacy preferences
    INSERT INTO recipe_manager.user_privacy_preferences (
        user_id,
        profile_visibility,
        recipe_visibility,
        activity_visibility,
        contact_info_visibility,
        data_sharing,
        analytics_tracking
    ) VALUES (
        NEW.user_id,
        'PUBLIC'::recipe_manager.profile_visibility_enum,
        'PUBLIC'::recipe_manager.profile_visibility_enum,
        'PUBLIC'::recipe_manager.profile_visibility_enum,
        'PRIVATE'::recipe_manager.profile_visibility_enum,
        FALSE,
        FALSE
    );

    -- Accessibility preferences
    INSERT INTO recipe_manager.user_accessibility_preferences (
        user_id,
        screen_reader,
        high_contrast,
        reduced_motion,
        large_text,
        keyboard_navigation
    ) VALUES (
        NEW.user_id,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE
    );

    -- Language preferences
    INSERT INTO recipe_manager.user_language_preferences (
        user_id,
        primary_language,
        secondary_language,
        translation_enabled
    ) VALUES (
        NEW.user_id,
        'EN'::recipe_manager.language_enum,
        NULL,
        FALSE
    );

    -- Security preferences
    INSERT INTO recipe_manager.user_security_preferences (
        user_id,
        two_factor_auth,
        login_notifications,
        session_timeout,
        password_requirements
    ) VALUES (
        NEW.user_id,
        FALSE,
        TRUE,
        FALSE,
        TRUE
    );

    -- Social preferences
    INSERT INTO recipe_manager.user_social_preferences (
        user_id,
        friend_requests,
        message_notifications,
        group_invites,
        share_activity
    ) VALUES (
        NEW.user_id,
        TRUE,
        TRUE,
        TRUE,
        TRUE
    );

    -- Sound preferences
    INSERT INTO recipe_manager.user_sound_preferences (
        user_id,
        notification_sounds,
        system_sounds,
        volume_level,
        mute_notifications
    ) VALUES (
        NEW.user_id,
        TRUE,
        TRUE,
        TRUE,
        FALSE
    );

    -- Theme preferences
    INSERT INTO recipe_manager.user_theme_preferences (
        user_id,
        dark_mode,
        light_mode,
        auto_theme,
        custom_theme
    ) VALUES (
        NEW.user_id,
        FALSE,
        TRUE,
        FALSE,
        NULL
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically create default preferences when a user is created
CREATE TRIGGER trigger_create_default_preferences
AFTER INSERT ON recipe_manager.users
FOR EACH ROW
EXECUTE FUNCTION recipe_manager.create_default_preferences();

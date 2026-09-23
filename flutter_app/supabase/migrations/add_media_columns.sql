-- Add video recording and file attachment support to community_events
-- Migration: Add media columns for video_record_url and additional_files

ALTER TABLE community_events
ADD COLUMN IF NOT EXISTS video_record_url TEXT,
ADD COLUMN IF NOT EXISTS audio_record_url TEXT,
ADD COLUMN IF NOT EXISTS additional_files JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS media_type VARCHAR(20) DEFAULT 'none' CHECK (media_type IN ('none', 'audio', 'video', 'file')),
ADD COLUMN IF NOT EXISTS file_count INTEGER DEFAULT 0;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_community_events_media_type ON community_events(media_type);

-- Add comments for clarity
COMMENT ON COLUMN community_events.video_record_url IS 'URL to recorded video file stored in Supabase Storage';
COMMENT ON COLUMN community_events.audio_record_url IS 'URL to recorded audio file stored in Supabase Storage';
COMMENT ON COLUMN community_events.additional_files IS 'JSON array of additional file objects {url, name, type, size, uploadedAt}';
COMMENT ON COLUMN community_events.media_type IS 'Type of media attachment: none, audio, video, or file';
COMMENT ON COLUMN community_events.file_count IS 'Count of additional files attached to this event';

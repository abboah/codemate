-- Migration: Add metadata columns to canvas_files for Playground Canvas
DO $$
BEGIN
    -- description: human-friendly title/summary for the file
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'canvas_files' AND column_name = 'description'
    ) THEN
        ALTER TABLE public.canvas_files ADD COLUMN description TEXT;
    END IF;

    -- file_type: 'code' | 'document'
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'canvas_files' AND column_name = 'file_type'
    ) THEN
        ALTER TABLE public.canvas_files ADD COLUMN file_type TEXT;
        -- Add a lightweight CHECK if possible
        BEGIN
            ALTER TABLE public.canvas_files
                ADD CONSTRAINT canvas_files_file_type_check CHECK (file_type IN ('code','document'));
        EXCEPTION WHEN duplicate_object THEN
            -- constraint already exists
        END;
    END IF;

    -- can_implement_in_canvas: whether we can run this in the preview (web-view)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'canvas_files' AND column_name = 'can_implement_in_canvas'
    ) THEN
        ALTER TABLE public.canvas_files ADD COLUMN can_implement_in_canvas BOOLEAN DEFAULT FALSE;
    END IF;

    -- version_number: integer version to help with updates
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'canvas_files' AND column_name = 'version_number'
    ) THEN
        ALTER TABLE public.canvas_files ADD COLUMN version_number INTEGER DEFAULT 1;
    END IF;
END$$;

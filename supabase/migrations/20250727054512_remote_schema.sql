create sequence "public"."file_access_logs_id_seq";

create sequence "public"."followers_id_seq";

create sequence "public"."saved_notes_id_seq";

create table "public"."events" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text not null,
    "date" timestamp with time zone not null,
    "created_at" timestamp with time zone default now()
);


alter table "public"."events" enable row level security;

create table "public"."file_access_logs" (
    "id" integer not null default nextval('file_access_logs_id_seq'::regclass),
    "user_id" uuid not null,
    "file_url" text not null,
    "file_name" text,
    "access_time" timestamp with time zone default now(),
    "device_info" text,
    "action" text default 'view'::text
);


alter table "public"."file_access_logs" enable row level security;

create table "public"."followers" (
    "id" integer not null default nextval('followers_id_seq'::regclass),
    "follower_id" uuid not null,
    "followed_id" uuid not null,
    "created_at" timestamp with time zone default now()
);


alter table "public"."followers" enable row level security;

create table "public"."forum_posts" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text not null,
    "content" text not null,
    "description" text,
    "created_at" timestamp with time zone default now(),
    "upvotes" integer not null default 0,
    "downvotes" integer not null default 0
);


alter table "public"."forum_posts" enable row level security;

create table "public"."forum_replies" (
    "id" uuid not null default gen_random_uuid(),
    "post_id" uuid,
    "user_id" uuid not null,
    "reply_content" text not null,
    "likes" integer default 0,
    "created_at" timestamp with time zone default now()
);


alter table "public"."forum_replies" enable row level security;

create table "public"."note_likes" (
    "note_id" uuid not null,
    "user_id" uuid not null,
    "liked_at" timestamp with time zone not null default now()
);


alter table "public"."note_likes" enable row level security;

create table "public"."note_views" (
    "note_id" uuid not null,
    "user_id" uuid not null,
    "viewed_at" timestamp with time zone not null default now()
);


alter table "public"."note_views" enable row level security;

create table "public"."notes" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "title" text not null,
    "description" text,
    "content" text,
    "file_url" text,
    "file_name" text,
    "file_size" bigint default 0,
    "file_type" text,
    "tags" text[] default '{}'::text[],
    "is_public" boolean default false,
    "created_at" timestamp with time zone default now(),
    "views_count" integer default 0,
    "likes_count" integer default 0,
    "view_count" integer default 0,
    "like_count" integer default 0,
    "storage_type" text
);


alter table "public"."notes" enable row level security;

create table "public"."payout_transactions" (
    "id" uuid not null default uuid_generate_v4(),
    "user_id" uuid not null,
    "amount" numeric(10,2) not null,
    "status" character varying(20) not null,
    "payment_method" character varying(50) not null,
    "transaction_date" timestamp with time zone default now(),
    "notes" text
);


create table "public"."post_votes" (
    "post_id" uuid not null,
    "user_id" uuid not null,
    "vote_type" smallint not null,
    "created_at" timestamp with time zone not null default now()
);


alter table "public"."post_votes" enable row level security;

create table "public"."profiles" (
    "id" uuid not null,
    "name" text not null,
    "username" text not null,
    "email" text,
    "profile_picture" text,
    "bio" text,
    "university" text,
    "storage_used" bigint default 0,
    "followers_count" integer default 0,
    "following_count" integer default 0,
    "role" text default 'Student'::text,
    "provider" text default 'Email'::text,
    "created_at" timestamp with time zone default now(),
    "last_login" timestamp with time zone default now(),
    "payout_eligible" boolean not null default false
);


alter table "public"."profiles" enable row level security;

create table "public"."saved_notes" (
    "id" integer not null default nextval('saved_notes_id_seq'::regclass),
    "user_id" uuid not null,
    "note_id" uuid not null,
    "saved_at" timestamp with time zone default now()
);


alter table "public"."saved_notes" enable row level security;

alter sequence "public"."file_access_logs_id_seq" owned by "public"."file_access_logs"."id";

alter sequence "public"."followers_id_seq" owned by "public"."followers"."id";

alter sequence "public"."saved_notes_id_seq" owned by "public"."saved_notes"."id";

CREATE UNIQUE INDEX events_pkey ON public.events USING btree (id);

CREATE INDEX events_user_id_date_idx ON public.events USING btree (user_id, date);

CREATE UNIQUE INDEX file_access_logs_pkey ON public.file_access_logs USING btree (id);

CREATE INDEX file_access_logs_user_id_idx ON public.file_access_logs USING btree (user_id);

CREATE INDEX followers_followed_id_idx ON public.followers USING btree (followed_id);

CREATE UNIQUE INDEX followers_follower_id_followed_id_key ON public.followers USING btree (follower_id, followed_id);

CREATE INDEX followers_follower_id_idx ON public.followers USING btree (follower_id);

CREATE UNIQUE INDEX followers_pkey ON public.followers USING btree (id);

CREATE UNIQUE INDEX forum_posts_pkey ON public.forum_posts USING btree (id);

CREATE UNIQUE INDEX forum_replies_pkey ON public.forum_replies USING btree (id);

CREATE INDEX idx_forum_posts_created_at ON public.forum_posts USING btree (created_at DESC);

CREATE INDEX idx_forum_posts_upvotes ON public.forum_posts USING btree (upvotes DESC);

CREATE INDEX idx_forum_posts_upvotes_created_at ON public.forum_posts USING btree (upvotes DESC, created_at DESC);

CREATE INDEX idx_notes_is_public ON public.notes USING btree (is_public);

CREATE INDEX idx_notes_public ON public.notes USING btree (is_public) WHERE (is_public = true);

CREATE INDEX idx_notes_tags ON public.notes USING gin (tags);

CREATE INDEX idx_notes_user_id ON public.notes USING btree (user_id);

CREATE INDEX note_likes_note_id_idx ON public.note_likes USING btree (note_id);

CREATE UNIQUE INDEX note_likes_pkey ON public.note_likes USING btree (note_id, user_id);

CREATE INDEX note_likes_user_id_idx ON public.note_likes USING btree (user_id);

CREATE INDEX note_views_note_id_idx ON public.note_views USING btree (note_id);

CREATE UNIQUE INDEX note_views_pkey ON public.note_views USING btree (note_id, user_id);

CREATE INDEX note_views_user_id_idx ON public.note_views USING btree (user_id);

CREATE INDEX notes_is_public_idx ON public.notes USING btree (is_public);

CREATE INDEX notes_like_count_idx ON public.notes USING btree (like_count DESC);

CREATE UNIQUE INDEX notes_pkey ON public.notes USING btree (id);

CREATE INDEX notes_tags_idx ON public.notes USING gin (tags);

CREATE INDEX notes_user_id_idx ON public.notes USING btree (user_id);

CREATE INDEX notes_view_count_idx ON public.notes USING btree (view_count DESC);

CREATE UNIQUE INDEX payout_transactions_pkey ON public.payout_transactions USING btree (id);

CREATE UNIQUE INDEX post_votes_pkey ON public.post_votes USING btree (post_id, user_id);

CREATE UNIQUE INDEX profiles_email_key ON public.profiles USING btree (email);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX profiles_username_key ON public.profiles USING btree (username);

CREATE UNIQUE INDEX saved_notes_pkey ON public.saved_notes USING btree (id);

CREATE INDEX saved_notes_user_id_idx ON public.saved_notes USING btree (user_id);

CREATE UNIQUE INDEX saved_notes_user_id_note_id_key ON public.saved_notes USING btree (user_id, note_id);

alter table "public"."events" add constraint "events_pkey" PRIMARY KEY using index "events_pkey";

alter table "public"."file_access_logs" add constraint "file_access_logs_pkey" PRIMARY KEY using index "file_access_logs_pkey";

alter table "public"."followers" add constraint "followers_pkey" PRIMARY KEY using index "followers_pkey";

alter table "public"."forum_posts" add constraint "forum_posts_pkey" PRIMARY KEY using index "forum_posts_pkey";

alter table "public"."forum_replies" add constraint "forum_replies_pkey" PRIMARY KEY using index "forum_replies_pkey";

alter table "public"."note_likes" add constraint "note_likes_pkey" PRIMARY KEY using index "note_likes_pkey";

alter table "public"."note_views" add constraint "note_views_pkey" PRIMARY KEY using index "note_views_pkey";

alter table "public"."notes" add constraint "notes_pkey" PRIMARY KEY using index "notes_pkey";

alter table "public"."payout_transactions" add constraint "payout_transactions_pkey" PRIMARY KEY using index "payout_transactions_pkey";

alter table "public"."post_votes" add constraint "post_votes_pkey" PRIMARY KEY using index "post_votes_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."saved_notes" add constraint "saved_notes_pkey" PRIMARY KEY using index "saved_notes_pkey";

alter table "public"."events" add constraint "events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) not valid;

alter table "public"."events" validate constraint "events_user_id_fkey";

alter table "public"."file_access_logs" add constraint "file_access_logs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) not valid;

alter table "public"."file_access_logs" validate constraint "file_access_logs_user_id_fkey";

alter table "public"."followers" add constraint "followers_followed_id_fkey" FOREIGN KEY (followed_id) REFERENCES profiles(id) not valid;

alter table "public"."followers" validate constraint "followers_followed_id_fkey";

alter table "public"."followers" add constraint "followers_follower_id_fkey" FOREIGN KEY (follower_id) REFERENCES profiles(id) not valid;

alter table "public"."followers" validate constraint "followers_follower_id_fkey";

alter table "public"."followers" add constraint "followers_follower_id_followed_id_key" UNIQUE using index "followers_follower_id_followed_id_key";

alter table "public"."forum_posts" add constraint "forum_posts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) not valid;

alter table "public"."forum_posts" validate constraint "forum_posts_user_id_fkey";

alter table "public"."forum_replies" add constraint "forum_replies_post_id_fkey" FOREIGN KEY (post_id) REFERENCES forum_posts(id) ON DELETE CASCADE not valid;

alter table "public"."forum_replies" validate constraint "forum_replies_post_id_fkey";

alter table "public"."forum_replies" add constraint "forum_replies_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) not valid;

alter table "public"."forum_replies" validate constraint "forum_replies_user_id_fkey";

alter table "public"."note_likes" add constraint "note_likes_note_id_fkey" FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE not valid;

alter table "public"."note_likes" validate constraint "note_likes_note_id_fkey";

alter table "public"."note_likes" add constraint "note_likes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."note_likes" validate constraint "note_likes_user_id_fkey";

alter table "public"."note_views" add constraint "note_views_note_id_fkey" FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE not valid;

alter table "public"."note_views" validate constraint "note_views_note_id_fkey";

alter table "public"."note_views" add constraint "note_views_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."note_views" validate constraint "note_views_user_id_fkey";

alter table "public"."notes" add constraint "notes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) not valid;

alter table "public"."notes" validate constraint "notes_user_id_fkey";

alter table "public"."payout_transactions" add constraint "payout_transactions_status_check" CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying])::text[]))) not valid;

alter table "public"."payout_transactions" validate constraint "payout_transactions_status_check";

alter table "public"."payout_transactions" add constraint "payout_transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE not valid;

alter table "public"."payout_transactions" validate constraint "payout_transactions_user_id_fkey";

alter table "public"."post_votes" add constraint "post_votes_post_id_fkey" FOREIGN KEY (post_id) REFERENCES forum_posts(id) ON DELETE CASCADE not valid;

alter table "public"."post_votes" validate constraint "post_votes_post_id_fkey";

alter table "public"."post_votes" add constraint "post_votes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE not valid;

alter table "public"."post_votes" validate constraint "post_votes_user_id_fkey";

alter table "public"."post_votes" add constraint "post_votes_vote_type_check" CHECK ((vote_type = ANY (ARRAY['-1'::integer, 1]))) not valid;

alter table "public"."post_votes" validate constraint "post_votes_vote_type_check";

alter table "public"."profiles" add constraint "profiles_email_key" UNIQUE using index "profiles_email_key";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_username_key" UNIQUE using index "profiles_username_key";

alter table "public"."saved_notes" add constraint "saved_notes_note_id_fkey" FOREIGN KEY (note_id) REFERENCES notes(id) not valid;

alter table "public"."saved_notes" validate constraint "saved_notes_note_id_fkey";

alter table "public"."saved_notes" add constraint "saved_notes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) not valid;

alter table "public"."saved_notes" validate constraint "saved_notes_user_id_fkey";

alter table "public"."saved_notes" add constraint "saved_notes_user_id_note_id_key" UNIQUE using index "saved_notes_user_id_note_id_key";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.cleanup_orphaned_files(user_id_param uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  orphaned_count INTEGER := 0;
BEGIN
  -- This is a stub function; in a real environment,
  -- you would need to implement interaction with storage
  -- using server-side functions and triggers
  RETURN orphaned_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_unique_like(note_id text, user_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- Create a unique ID for the like
  insert into note_likes (id, note_id, user_id, liked_at)
  values (user_id || '_' || note_id, note_id, user_id, now())
  on conflict (id) do nothing;
  
  -- Increment like count even if there was a conflict
  update notes
  set like_count = coalesce(like_count, 0) + 1
  where id = note_id
    and not exists (
      select 1 from note_likes
      where note_id = create_unique_like.note_id
      and user_id = create_unique_like.user_id
      and liked_at < now() - interval '5 seconds'
    );
  
  return true;
exception
  when others then
    return false;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_unique_view(note_id text, user_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  view_id text := user_id || '_' || note_id;
  view_existed boolean;
begin
  -- Check if view already exists
  select exists(
    select 1 from note_views
    where id = view_id
  ) into view_existed;
  
  if view_existed then
    -- Just update the timestamp
    update note_views
    set viewed_at = now()
    where id = view_id;
    
    return false; -- No new view
  else
    -- Create new view record
    insert into note_views (id, note_id, user_id, viewed_at)
    values (view_id, note_id, user_id, now());
    
    -- Increment view count
    update notes
    set view_count = coalesce(view_count, 0) + 1
    where id = note_id;
    
    return true; -- New view created
  end if;
exception
  when others then
    return false;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.decrement_note_likes(note_id_param text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE notes
  SET like_count = GREATEST(like_count - 1, 0)
  WHERE id = note_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.decrement_note_likes(note_id_param uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE notes
  SET like_count = GREATEST(like_count - 1, 0)
  WHERE id = note_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.decrement_storage(user_uuid uuid, bytes_to_subtract bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.profiles
  SET storage_used = GREATEST(0, storage_used - bytes_to_subtract) -- Ensure storage doesn't go negative
  WHERE id = user_uuid;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_note_likes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM note_likes WHERE note_id = OLD.id;
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_note_views()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM note_views WHERE note_id = OLD.id;
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_saved_notes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM saved_notes WHERE note_id = OLD.id;
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_unique_like(note_id text, user_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  like_existed boolean;
begin
  -- Check if like exists first
  select exists(
    select 1 from note_likes
    where note_id = delete_unique_like.note_id
    and user_id = delete_unique_like.user_id
  ) into like_existed;
  
  if like_existed then
    -- Delete the like record
    delete from note_likes
    where note_id = delete_unique_like.note_id
    and user_id = delete_unique_like.user_id;
    
    -- Decrement like count, but ensure it doesn't go below zero
    update notes
    set like_count = greatest(0, coalesce(like_count, 0) - 1)
    where id = note_id;
  end if;
  
  return like_existed;
exception
  when others then
    return false;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_user_data()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  SET search_path = 'public';
  DELETE FROM storage.objects WHERE bucket_id = 'notes' AND owner = old.id;
  DELETE FROM storage.objects WHERE bucket_id = 'profile_pictures' AND owner = old.id;
  DELETE FROM public.notes WHERE user_id = old.id;
  DELETE FROM public.profiles WHERE id = old.id;
  RETURN old;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_user_data(user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Delete in reverse order of dependencies
  DELETE FROM followers WHERE follower_id = user_id OR followed_id = user_id;
  DELETE FROM saved_notes WHERE user_id = user_id;
  DELETE FROM note_likes WHERE user_id = user_id;
  DELETE FROM note_views WHERE user_id = user_id;
  DELETE FROM forum_replies WHERE user_id = user_id;
  DELETE FROM forum_posts WHERE user_id = user_id;
  DELETE FROM events WHERE user_id = user_id;
  DELETE FROM file_access_logs WHERE user_id = user_id;
  DELETE FROM notes WHERE user_id = user_id;
  DELETE FROM profiles WHERE id = user_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_forum_posts_with_details(p_sort_option text DEFAULT 'newest'::text, p_page_size integer DEFAULT 15, p_page_number integer DEFAULT 1)
 RETURNS TABLE(id uuid, user_id uuid, title text, description text, created_at timestamp with time zone, upvotes integer, downvotes integer, author_id uuid, author_name text, author_profile_picture text, reply_count bigint)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_offset INT;
BEGIN
    v_offset := (p_page_number - 1) * p_page_size;

    RETURN QUERY
    SELECT
        fp.id,
        fp.user_id,
        fp.title,
        fp.description, -- or fp.content, ensure your table has this
        fp.created_at,
        fp.upvotes,
        fp.downvotes,
        p.id AS author_id,
        p.name AS author_name,
        p.profile_picture AS author_profile_picture,
        (SELECT COUNT(*) FROM forum_replies fr WHERE fr.post_id = fp.id) AS reply_count
    FROM
        forum_posts fp
    LEFT JOIN
        profiles p ON fp.user_id = p.id
    ORDER BY
        CASE WHEN p_sort_option = 'newest' THEN fp.created_at END DESC NULLS LAST,
        CASE WHEN p_sort_option = 'top' THEN fp.upvotes END DESC NULLS LAST,
        CASE WHEN p_sort_option = 'top' THEN fp.downvotes END ASC NULLS LAST,
        CASE WHEN p_sort_option = 'top' THEN fp.created_at END DESC NULLS LAST,
        fp.id DESC -- Consistent secondary sort
    LIMIT p_page_size
    OFFSET v_offset;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_forum_replies_with_details(p_post_id uuid, p_page_size integer DEFAULT 20, p_page_number integer DEFAULT 1)
 RETURNS TABLE(id uuid, post_id uuid, user_id uuid, reply_content text, created_at timestamp with time zone, author_id uuid, author_name text, author_profile_picture text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_offset INT;
BEGIN
    v_offset := (p_page_number - 1) * p_page_size;

    RETURN QUERY
    SELECT
        fr.id,
        fr.post_id,
        fr.user_id,
        fr.reply_content,
        fr.created_at,
        -- fr.upvotes,
        -- fr.downvotes,
        p.id AS author_id,
        p.name AS author_name,
        p.profile_picture AS author_profile_picture
    FROM
        forum_replies fr
    LEFT JOIN
        profiles p ON fr.user_id = p.id
    WHERE
        fr.post_id = p_post_id
    ORDER BY
        fr.created_at ASC -- Typically oldest replies first for context
    LIMIT p_page_size
    OFFSET v_offset;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_popular_tags()
 RETURNS TABLE(tag_name text, tag_count bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT tag, COUNT(*) as count
  FROM notes, unnest(tags) tag
  GROUP BY tag
  ORDER BY count DESC
  LIMIT 10;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_profile_screen_data(p_profile_user_id uuid, p_requesting_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_profile RECORD;
    v_followers_count INT;
    v_following_count INT;
    v_is_following BOOLEAN;
BEGIN
    -- Get profile details
    SELECT id, username, name, university, bio, profile_picture
    INTO v_profile
    FROM profiles
    WHERE id = p_profile_user_id;

    IF v_profile IS NULL THEN
        -- Return a JSON object indicating the profile was not found
        RETURN json_build_object('error', 'Profile not found', 'profile', null);
    END IF;

    -- Get followers count (users following p_profile_user_id)
    SELECT COUNT(*)
    INTO v_followers_count
    FROM followers f
    WHERE f.followed_id = p_profile_user_id; -- CORRECTED: f.following_id to f.followed_id

    -- Get following count (users p_profile_user_id is following)
    SELECT COUNT(*)
    INTO v_following_count
    FROM followers f
    WHERE f.follower_id = p_profile_user_id; -- This line assumes 'follower_id' is correct

    -- Check if requesting user is following this profile
    IF p_requesting_user_id IS NULL OR p_profile_user_id = p_requesting_user_id THEN
        v_is_following := FALSE; 
    ELSE
        SELECT EXISTS (
            SELECT 1
            FROM followers f
            WHERE f.follower_id = p_requesting_user_id AND f.followed_id = p_profile_user_id -- CORRECTED: f.following_id to f.followed_id
        )
        INTO v_is_following;
    END IF;

    RETURN json_build_object(
        'profile', row_to_json(v_profile),
        'followers_count', v_followers_count,
        'following_count', v_following_count,
        'is_following', v_is_following
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_single_post_details(p_post_id uuid)
 RETURNS TABLE(id uuid, user_id uuid, title text, content text, created_at timestamp with time zone, upvotes integer, downvotes integer, author_id uuid, author_name text, author_profile_picture text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        fp.id,
        fp.user_id,
        fp.title,
        fp.content, -- or fp.description
        fp.created_at,
        fp.upvotes,
        fp.downvotes,
        p.id AS author_id,
        p.name AS author_name,
        p.profile_picture AS author_profile_picture
    FROM
        forum_posts fp
    LEFT JOIN
        profiles p ON fp.user_id = p.id
    WHERE
        fp.id = p_post_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_notes_paginated(p_profile_user_id uuid, p_requesting_user_id uuid, p_page_size integer DEFAULT 12, p_page_number integer DEFAULT 1)
 RETURNS TABLE(id uuid, user_id uuid, title text, content text, file_url text, file_name text, file_type text, is_public boolean, view_count integer, tags text[], created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_offset INT;
BEGIN
    v_offset := (p_page_number - 1) * p_page_size;

    RETURN QUERY
    SELECT
        n.id,
        n.user_id,
        n.title,
        n.content, -- Ensure this matches your 'notes' table column
        n.file_url,
        n.file_name,
        n.file_type,
        n.is_public,
        n.view_count,
        n.tags,
        n.created_at
        -- Select other fields corresponding to the RETURNS TABLE definition
    FROM
        notes n -- Ensure 'notes' is your actual table name
    WHERE
        n.user_id = p_profile_user_id
        AND (n.is_public = TRUE OR p_profile_user_id = p_requesting_user_id)
    ORDER BY
        n.created_at DESC
    LIMIT p_page_size
    OFFSET v_offset;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_total_views(user_id_param text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  total_views integer;
BEGIN
  SELECT COALESCE(SUM(view_count), 0) INTO total_views
  FROM notes
  WHERE user_id = user_id_param;
  
  RETURN total_views;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_total_views(user_id_param uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  total_views INTEGER;
BEGIN
  SELECT COALESCE(SUM(view_count), 0) INTO total_views
  FROM notes
  WHERE user_id = user_id_param;
  
  RETURN total_views;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  user_name TEXT;
  user_username TEXT;
  user_avatar_url TEXT;
  user_provider TEXT;
BEGIN
  -- Set a temporary, transaction-local "passcode". This is the key to the fix.
  -- The RLS policy will check for this exact setting.
  PERFORM set_config('app.allow_profile_creation', 'true', true);

  user_provider := new.raw_app_meta_data->>'provider';

  IF user_provider IS NOT NULL THEN
    user_name := new.raw_user_meta_data->>'full_name';
    user_avatar_url := new.raw_user_meta_data->>'avatar_url';
    user_username := COALESCE(new.raw_user_meta_data->>'user_name', split_part(new.email, '@', 1));
  ELSE
    user_name := new.raw_app_meta_data->>'name';
    user_username := new.raw_app_meta_data->>'username';
    user_avatar_url := NULL;
  END IF;

  INSERT INTO public.profiles (id, name, username, email, profile_picture, provider)
  VALUES (
    new.id,
    COALESCE(user_name, user_username, 'New User'),
    COALESCE(user_username, split_part(new.email, '@', 1)),
    new.email,
    user_avatar_url,
    COALESCE(user_provider, 'Email')
  );

  -- The 'app.allow_profile_creation' setting is automatically discarded at the end of the transaction.
  RETURN new;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_likes(note_id_param text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE notes
  SET like_count = like_count + 1
  WHERE id = note_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_likes(note_id_param uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE notes
  SET like_count = like_count + 1
  WHERE id = note_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_view(note_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  current_views INT;
  new_views INT;
BEGIN
  -- Get current view count
  SELECT view_count INTO current_views FROM notes WHERE id = note_id;
  
  -- Set to 0 if NULL
  IF current_views IS NULL THEN
    current_views := 0;
  END IF;
  
  -- Increment by 1
  new_views := current_views + 1;
  
  -- Update the note
  UPDATE notes SET view_count = new_views WHERE id = note_id;
  
  -- Return new count
  RETURN new_views;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_view_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  SET search_path = 'public';
  UPDATE notes SET view_count = view_count + 1 WHERE id = new.note_id;
  RETURN new;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_view_count(note_id text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  new_count integer;
begin
  update notes
  set view_count = coalesce(view_count, 0) + 1
  where id = note_id
  returning view_count into new_count;
  
  return new_count;
exception
  when others then
    return 0;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_view_count(note_id uuid, viewer_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  view_exists BOOLEAN;
  success BOOLEAN := FALSE;
BEGIN
  -- Check if this view already exists to prevent duplicates
  SELECT EXISTS(
    SELECT 1 FROM note_views
    WHERE note_id = $1 AND user_id = $2
  ) INTO view_exists;

  -- Only create a new view record if one doesn't exist
  IF NOT view_exists THEN
    -- Create view record first
    INSERT INTO note_views (note_id, user_id, viewed_at)
    VALUES ($1, $2, NOW());
    
    -- Atomically increment the view count in notes table
    UPDATE notes
    SET view_count = COALESCE(view_count, 0) + 1
    WHERE id = $1;
    
    success := TRUE;
  END IF;

  RETURN success;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_view_count(note_id_param uuid)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  new_count integer;
BEGIN
  UPDATE notes
  SET views_count = COALESCE(views_count, 0) + 1
  WHERE id = note_id_param
  RETURNING views_count INTO new_count;

  RETURN new_count;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_note_views(note_id_param uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- THIS IS THE FIX: Secure the search path
  SET search_path = 'public';

  -- Your existing code remains unchanged
  UPDATE notes SET view_count = view_count + 1 WHERE id = note_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_storage(user_uuid uuid, bytes_to_add bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.profiles
  SET storage_used = storage_used + bytes_to_add
  WHERE id = user_uuid;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_view_count(note_id_param text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE notes
  SET view_count = view_count + 1
  WHERE id = note_id_param;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.record_note_view(note_id text, user_id text, timestamp_param timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  view_id text := user_id || '_' || note_id;
  view_exists boolean;
begin
  -- Check if view already exists
  select exists(
    select 1 from note_views where id = view_id
  ) into view_exists;
  
  if view_exists then
    -- Update existing view timestamp
    update note_views
    set viewed_at = timestamp_param
    where id = view_id;
  else
    -- Insert new view
    insert into note_views (id, note_id, user_id, viewed_at)
    values (view_id, note_id, user_id, timestamp_param);
    
    -- Increment note view count
    update notes
    set view_count = coalesce(view_count, 0) + 1
    where id = note_id;
  end if;
  
  return true;
exception
  when others then
    return false;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.record_note_view(note_uuid uuid, viewer_uuid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  SET LOCAL search_path = 'public';
  INSERT INTO public.note_views (note_id, user_id)
  VALUES (note_uuid, viewer_uuid)
  ON CONFLICT (note_id, user_id) DO NOTHING;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.search_notes(search_query text, current_user_id uuid)
 RETURNS SETOF notes
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT DISTINCT n.*
  FROM notes n
  WHERE (n.is_public = true OR n.user_id = current_user_id)
  AND (
    n.title ILIKE '%' || search_query || '%' OR
    n.content ILIKE '%' || search_query || '%' OR
    EXISTS (
      SELECT 1 FROM unnest(n.tags) tag
      WHERE tag ILIKE '%' || search_query || '%'
    )
  )
  ORDER BY n.created_at DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.search_notes(search_term text)
 RETURNS TABLE(id uuid, user_id uuid, title text, description text, tags text[], file_path text, file_type text, view_count integer, like_count integer, created_at timestamp with time zone, username text, profile_picture_url text)
 LANGUAGE plpgsql
AS $function$
BEGIN
  SET search_path = 'public';
  RETURN QUERY
  SELECT n.id, n.user_id, n.title, n.description, n.tags, n.file_path,
         n.file_type, n.view_count, n.like_count, n.created_at,
         p.username, p.profile_picture_url
  FROM notes AS n
  JOIN profiles AS p ON n.user_id = p.id
  WHERE
    n.title ILIKE '%' || search_term || '%' OR
    n.description ILIKE '%' || search_term || '%' OR
    p.username ILIKE '%' || search_term || '%' OR
    search_term = ANY(n.tags);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_note_like(note_id text, user_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  like_id text := user_id || '_' || note_id;
  like_exists boolean;
  current_count integer;
  new_count integer;
  is_liked boolean;
begin
  -- Check if like already exists
  select exists(
    select 1 from note_likes where id = like_id
  ) into like_exists;
  
  -- Get current like count
  select like_count from notes where id = note_id into current_count;
  current_count := coalesce(current_count, 0);
  
  if like_exists then
    -- Unlike: Delete the like record
    delete from note_likes where id = like_id;
    
    -- Decrement like count (minimum 0)
    new_count := greatest(0, current_count - 1);
    is_liked := false;
  else
    -- Like: Insert new like record
    insert into note_likes (id, note_id, user_id, liked_at)
    values (like_id, note_id, user_id, now());
    
    -- Increment like count
    new_count := current_count + 1;
    is_liked := true;
  end if;
  
  -- Update note like count
  update notes
  set like_count = new_count
  where id = note_id;
  
  -- Return the new state
  return json_build_object(
    'is_liked', is_liked,
    'new_like_count', new_count
  );
exception
  when others then
    return json_build_object(
      'error', sqlerrm,
      'is_liked', like_exists,
      'new_like_count', current_count
    );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_note_like(note_id uuid, user_id uuid, is_currently_liked boolean)
 RETURNS TABLE(new_like_count integer, is_liked boolean)
 LANGUAGE plpgsql
AS $function$
DECLARE
  current_likes INT;
  new_likes INT;
  like_exists BOOLEAN;
  new_like_status BOOLEAN;
BEGIN
  -- Check if like record exists
  SELECT EXISTS(
    SELECT 1 FROM note_likes 
    WHERE note_id = toggle_note_like.note_id AND user_id = toggle_note_like.user_id
  ) INTO like_exists;
  
  -- Get current like count
  SELECT like_count INTO current_likes FROM notes WHERE id = note_id;
  
  -- Set to 0 if NULL
  IF current_likes IS NULL THEN
    current_likes := 0;
  END IF;
  
  -- Determine action based on database state
  IF like_exists THEN
    -- Unlike - delete the record
    DELETE FROM note_likes 
    WHERE note_id = toggle_note_like.note_id AND user_id = toggle_note_like.user_id;
    
    -- Decrement count (with safeguard)
    new_likes := GREATEST(0, current_likes - 1);
    new_like_status := FALSE;
  ELSE
    -- Like - create a new record
    INSERT INTO note_likes (id, note_id, user_id, liked_at)
    VALUES (
      toggle_note_like.user_id || '_' || toggle_note_like.note_id,
      toggle_note_like.note_id,
      toggle_note_like.user_id,
      NOW()
    );
    
    -- Increment count
    new_likes := current_likes + 1;
    new_like_status := TRUE;
  END IF;
  
  -- Update note like count
  UPDATE notes SET like_count = new_likes WHERE id = note_id;
  
  -- Return results
  RETURN QUERY SELECT new_likes, new_like_status;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_note_like(note_uuid uuid, liker_uuid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  is_currently_liked boolean;
  new_like_count integer;
BEGIN
  SET LOCAL search_path = 'public';

  -- Check if the user already likes this note.
  SELECT EXISTS (
    SELECT 1 FROM public.note_likes WHERE note_id = note_uuid AND user_id = liker_uuid
  ) INTO is_currently_liked;

  -- Perform the like/unlike action.
  IF is_currently_liked THEN
    DELETE FROM public.note_likes WHERE note_id = note_uuid AND user_id = liker_uuid;
  ELSE
    INSERT INTO public.note_likes (note_id, user_id) VALUES (note_uuid, liker_uuid);
  END IF;

  -- After the action, get the new like count to return to the app.
  -- The actual update to the 'notes' table will be handled by the trigger.
  SELECT COUNT(*) INTO new_like_count FROM public.note_likes WHERE note_id = note_uuid;

  -- Return the JSON object the app expects.
  RETURN jsonb_build_object(
    'success', true,
    'newLikeCount', new_like_count,
    'isLiked', NOT is_currently_liked
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_note_like(p_note_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  current_user_id uuid := auth.uid();
BEGIN
  -- SECURITY FIX: Explicitly set the search path.
  SET search_path = 'public';

  -- Check if the current user has already liked this note
  IF EXISTS(SELECT 1 FROM note_likes WHERE note_id = p_note_id AND user_id = current_user_id) THEN
    -- If liked, remove the like
    DELETE FROM note_likes WHERE note_id = p_note_id AND user_id = current_user_id;
  ELSE
    -- If not liked, add the like
    INSERT INTO note_likes (note_id, user_id) VALUES (p_note_id, current_user_id);
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.toggle_post_vote(post_uuid uuid, voter_uuid uuid, vote_value smallint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  current_vote smallint;
  new_upvotes int;
  new_downvotes int;
  vote_change_up int := 0;
  vote_change_down int := 0;
  final_user_vote smallint; -- The actual vote type stored or 0 if removed
BEGIN
  -- Check existing vote
  SELECT vote_type INTO current_vote
  FROM public.post_votes
  WHERE post_id = post_uuid AND user_id = voter_uuid;

  -- Determine action based on desired new state (vote_value from app)
  IF vote_value = 0 THEN
      -- Intent is to REMOVE the vote
      IF current_vote IS NOT NULL THEN
          -- Only delete and adjust counts if a vote actually exists
          DELETE FROM public.post_votes
          WHERE post_id = post_uuid AND user_id = voter_uuid;
          -- Adjust counts based on the vote being removed
          IF current_vote = 1 THEN vote_change_up := -1; ELSE vote_change_down := -1; END IF;
      END IF;
      final_user_vote := 0; -- User vote is now neutral

  ELSIF vote_value = current_vote THEN
      -- User clicked the same button again - App sends 0, so this block is less likely needed,
      -- but kept as safety: If app somehow sends same vote value, do nothing to counts.
      final_user_vote := current_vote;

  ELSE
      -- Intent is to INSERT a new vote (1 or -1) or UPDATE an existing one
      -- Use INSERT ON CONFLICT (Upsert) to handle both inserting and updating
      INSERT INTO public.post_votes (post_id, user_id, vote_type)
      VALUES (post_uuid, voter_uuid, vote_value)
      ON CONFLICT (post_id, user_id) DO UPDATE
      SET vote_type = excluded.vote_type; -- Update to the new vote_value if row exists

      -- Calculate count changes based on the transition from current_vote to vote_value
      IF current_vote IS NULL THEN -- Was neutral, now 1 or -1
          IF vote_value = 1 THEN vote_change_up := 1; ELSE vote_change_down := 1; END IF;
      ELSIF current_vote = 1 AND vote_value = -1 THEN -- Was up, now down
          vote_change_up := -1; vote_change_down := 1;
      ELSIF current_vote = -1 AND vote_value = 1 THEN -- Was down, now up
          vote_change_up := 1; vote_change_down := -1;
      -- else: vote didn't actually change (handled by upsert, no count change needed)
      END IF;
      final_user_vote := vote_value; -- User vote is the new value
  END IF;

  -- Atomically update counts on the forum_posts table if changes occurred
  IF vote_change_up <> 0 OR vote_change_down <> 0 THEN
      UPDATE public.forum_posts
      SET
        upvotes = GREATEST(0, upvotes + vote_change_up),    -- Ensure counts don't go below 0
        downvotes = GREATEST(0, downvotes + vote_change_down)
      WHERE id = post_uuid
      RETURNING upvotes, downvotes INTO new_upvotes, new_downvotes;
  ELSE
      -- If no change in votes, just fetch current counts
       SELECT upvotes, downvotes INTO new_upvotes, new_downvotes
       FROM public.forum_posts WHERE id = post_uuid;
  END IF;


  -- Handle case where post might have been deleted concurrently or counts weren't updated
  IF new_upvotes IS NULL OR new_downvotes IS NULL THEN
     -- Attempt to fetch counts again if update didn't return them
     SELECT upvotes, downvotes INTO new_upvotes, new_downvotes
     FROM public.forum_posts WHERE id = post_uuid;
     -- If post is gone entirely, default counts to 0
     IF NOT FOUND THEN
        new_upvotes := 0;
        new_downvotes := 0;
        final_user_vote := 0; -- Vote becomes irrelevant
     END IF;
  END IF;

  -- Return the result - Use COALESCE to handle potential NULLs safely
  RETURN jsonb_build_object(
    'success', true,
    'new_upvotes', COALESCE(new_upvotes, 0),
    'new_downvotes', COALESCE(new_downvotes, 0),
    'user_vote', final_user_vote -- The actual final state (0, 1, or -1)
  );

EXCEPTION
  WHEN others THEN
    -- Log the error internally on the server if desired
    RAISE WARNING '[toggle_post_vote] Error for post % by user %: %', post_uuid, voter_uuid, SQLERRM;
    -- Return failure status
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM, -- Send back the actual SQL error message
      'new_upvotes', 0,
      'new_downvotes', 0,
      'user_vote', COALESCE(current_vote, 0) -- Return previous vote on error if known
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_follower_counts()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_followed_id uuid;
    v_follower_id uuid;
BEGIN
    SET search_path = 'public';
    IF (TG_OP = 'INSERT') THEN
        v_followed_id := NEW.followed_id;
        v_follower_id := NEW.follower_id;
    ELSE
        v_followed_id := OLD.followed_id;
        v_follower_id := OLD.follower_id;
    END IF;
    UPDATE profiles SET following_count = (SELECT COUNT(*) FROM followers WHERE follower_id = v_follower_id) WHERE id = v_follower_id;
    UPDATE profiles SET followers_count = (SELECT COUNT(*) FROM followers WHERE followed_id = v_followed_id) WHERE id = v_followed_id;
    RETURN NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_followers_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE profiles
    SET followers_count = followers_count + 1
    WHERE id = NEW.followed_id;
    
    UPDATE profiles
    SET following_count = following_count + 1
    WHERE id = NEW.follower_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE profiles
    SET followers_count = followers_count - 1
    WHERE id = OLD.followed_id;
    
    UPDATE profiles
    SET following_count = following_count - 1
    WHERE id = OLD.follower_id;
  END IF;
  RETURN NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_like_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE notes
    SET like_count = like_count + 1
    WHERE id = NEW.note_id;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE notes
    SET like_count = GREATEST(like_count - 1, 0)  -- Ensure it doesn't go below 0
    WHERE id = OLD.note_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_note_like_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  new_like_count int;
BEGIN
    SET LOCAL search_path = 'public';
    -- Calculate the new count based on the note_id from the changed row.
    SELECT COUNT(*) INTO new_like_count
    FROM public.note_likes
    WHERE note_id = COALESCE(NEW.note_id, OLD.note_id);

    -- Update the 'notes' table with the new, correct count.
    UPDATE public.notes
    SET like_count = new_like_count
    WHERE id = COALESCE(NEW.note_id, OLD.note_id);

    RETURN NULL;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_note_like_count(note_id_param uuid, increment_param boolean)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  new_count integer;
BEGIN
  IF increment_param THEN
    UPDATE notes
    SET likes_count = COALESCE(likes_count, 0) + 1
    WHERE id = note_id_param
    RETURNING likes_count INTO new_count;
  ELSE
    UPDATE notes
    SET likes_count = GREATEST(COALESCE(likes_count, 0) - 1, 0) -- Prevent going below 0
    WHERE id = note_id_param
    RETURNING likes_count INTO new_count;
  END IF;

  RETURN COALESCE(new_count, 0); -- Ensure returning 0 if note not found or count is null
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_note_view_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE notes 
  SET view_count = (
    SELECT COUNT(*) FROM note_views WHERE note_id = NEW.note_id
  )
  WHERE id = NEW.note_id;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_storage_on_note_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    SET search_path = 'public';
    IF OLD.file_path IS NOT NULL THEN
        PERFORM storage.delete_object('notes', OLD.file_path);
    END IF;
    RETURN OLD;
END;
$function$
;

grant delete on table "public"."events" to "anon";

grant insert on table "public"."events" to "anon";

grant references on table "public"."events" to "anon";

grant select on table "public"."events" to "anon";

grant trigger on table "public"."events" to "anon";

grant truncate on table "public"."events" to "anon";

grant update on table "public"."events" to "anon";

grant delete on table "public"."events" to "authenticated";

grant insert on table "public"."events" to "authenticated";

grant references on table "public"."events" to "authenticated";

grant select on table "public"."events" to "authenticated";

grant trigger on table "public"."events" to "authenticated";

grant truncate on table "public"."events" to "authenticated";

grant update on table "public"."events" to "authenticated";

grant delete on table "public"."events" to "service_role";

grant insert on table "public"."events" to "service_role";

grant references on table "public"."events" to "service_role";

grant select on table "public"."events" to "service_role";

grant trigger on table "public"."events" to "service_role";

grant truncate on table "public"."events" to "service_role";

grant update on table "public"."events" to "service_role";

grant delete on table "public"."file_access_logs" to "anon";

grant insert on table "public"."file_access_logs" to "anon";

grant references on table "public"."file_access_logs" to "anon";

grant select on table "public"."file_access_logs" to "anon";

grant trigger on table "public"."file_access_logs" to "anon";

grant truncate on table "public"."file_access_logs" to "anon";

grant update on table "public"."file_access_logs" to "anon";

grant delete on table "public"."file_access_logs" to "authenticated";

grant insert on table "public"."file_access_logs" to "authenticated";

grant references on table "public"."file_access_logs" to "authenticated";

grant select on table "public"."file_access_logs" to "authenticated";

grant trigger on table "public"."file_access_logs" to "authenticated";

grant truncate on table "public"."file_access_logs" to "authenticated";

grant update on table "public"."file_access_logs" to "authenticated";

grant delete on table "public"."file_access_logs" to "service_role";

grant insert on table "public"."file_access_logs" to "service_role";

grant references on table "public"."file_access_logs" to "service_role";

grant select on table "public"."file_access_logs" to "service_role";

grant trigger on table "public"."file_access_logs" to "service_role";

grant truncate on table "public"."file_access_logs" to "service_role";

grant update on table "public"."file_access_logs" to "service_role";

grant delete on table "public"."followers" to "anon";

grant insert on table "public"."followers" to "anon";

grant references on table "public"."followers" to "anon";

grant select on table "public"."followers" to "anon";

grant trigger on table "public"."followers" to "anon";

grant truncate on table "public"."followers" to "anon";

grant update on table "public"."followers" to "anon";

grant delete on table "public"."followers" to "authenticated";

grant insert on table "public"."followers" to "authenticated";

grant references on table "public"."followers" to "authenticated";

grant select on table "public"."followers" to "authenticated";

grant trigger on table "public"."followers" to "authenticated";

grant truncate on table "public"."followers" to "authenticated";

grant update on table "public"."followers" to "authenticated";

grant delete on table "public"."followers" to "service_role";

grant insert on table "public"."followers" to "service_role";

grant references on table "public"."followers" to "service_role";

grant select on table "public"."followers" to "service_role";

grant trigger on table "public"."followers" to "service_role";

grant truncate on table "public"."followers" to "service_role";

grant update on table "public"."followers" to "service_role";

grant delete on table "public"."forum_posts" to "anon";

grant insert on table "public"."forum_posts" to "anon";

grant references on table "public"."forum_posts" to "anon";

grant select on table "public"."forum_posts" to "anon";

grant trigger on table "public"."forum_posts" to "anon";

grant truncate on table "public"."forum_posts" to "anon";

grant update on table "public"."forum_posts" to "anon";

grant delete on table "public"."forum_posts" to "authenticated";

grant insert on table "public"."forum_posts" to "authenticated";

grant references on table "public"."forum_posts" to "authenticated";

grant select on table "public"."forum_posts" to "authenticated";

grant trigger on table "public"."forum_posts" to "authenticated";

grant truncate on table "public"."forum_posts" to "authenticated";

grant update on table "public"."forum_posts" to "authenticated";

grant delete on table "public"."forum_posts" to "service_role";

grant insert on table "public"."forum_posts" to "service_role";

grant references on table "public"."forum_posts" to "service_role";

grant select on table "public"."forum_posts" to "service_role";

grant trigger on table "public"."forum_posts" to "service_role";

grant truncate on table "public"."forum_posts" to "service_role";

grant update on table "public"."forum_posts" to "service_role";

grant delete on table "public"."forum_replies" to "anon";

grant insert on table "public"."forum_replies" to "anon";

grant references on table "public"."forum_replies" to "anon";

grant select on table "public"."forum_replies" to "anon";

grant trigger on table "public"."forum_replies" to "anon";

grant truncate on table "public"."forum_replies" to "anon";

grant update on table "public"."forum_replies" to "anon";

grant delete on table "public"."forum_replies" to "authenticated";

grant insert on table "public"."forum_replies" to "authenticated";

grant references on table "public"."forum_replies" to "authenticated";

grant select on table "public"."forum_replies" to "authenticated";

grant trigger on table "public"."forum_replies" to "authenticated";

grant truncate on table "public"."forum_replies" to "authenticated";

grant update on table "public"."forum_replies" to "authenticated";

grant delete on table "public"."forum_replies" to "service_role";

grant insert on table "public"."forum_replies" to "service_role";

grant references on table "public"."forum_replies" to "service_role";

grant select on table "public"."forum_replies" to "service_role";

grant trigger on table "public"."forum_replies" to "service_role";

grant truncate on table "public"."forum_replies" to "service_role";

grant update on table "public"."forum_replies" to "service_role";

grant delete on table "public"."note_likes" to "anon";

grant insert on table "public"."note_likes" to "anon";

grant references on table "public"."note_likes" to "anon";

grant select on table "public"."note_likes" to "anon";

grant trigger on table "public"."note_likes" to "anon";

grant truncate on table "public"."note_likes" to "anon";

grant update on table "public"."note_likes" to "anon";

grant delete on table "public"."note_likes" to "authenticated";

grant insert on table "public"."note_likes" to "authenticated";

grant references on table "public"."note_likes" to "authenticated";

grant select on table "public"."note_likes" to "authenticated";

grant trigger on table "public"."note_likes" to "authenticated";

grant truncate on table "public"."note_likes" to "authenticated";

grant update on table "public"."note_likes" to "authenticated";

grant delete on table "public"."note_likes" to "service_role";

grant insert on table "public"."note_likes" to "service_role";

grant references on table "public"."note_likes" to "service_role";

grant select on table "public"."note_likes" to "service_role";

grant trigger on table "public"."note_likes" to "service_role";

grant truncate on table "public"."note_likes" to "service_role";

grant update on table "public"."note_likes" to "service_role";

grant delete on table "public"."note_views" to "anon";

grant insert on table "public"."note_views" to "anon";

grant references on table "public"."note_views" to "anon";

grant select on table "public"."note_views" to "anon";

grant trigger on table "public"."note_views" to "anon";

grant truncate on table "public"."note_views" to "anon";

grant update on table "public"."note_views" to "anon";

grant delete on table "public"."note_views" to "authenticated";

grant insert on table "public"."note_views" to "authenticated";

grant references on table "public"."note_views" to "authenticated";

grant select on table "public"."note_views" to "authenticated";

grant trigger on table "public"."note_views" to "authenticated";

grant truncate on table "public"."note_views" to "authenticated";

grant update on table "public"."note_views" to "authenticated";

grant delete on table "public"."note_views" to "service_role";

grant insert on table "public"."note_views" to "service_role";

grant references on table "public"."note_views" to "service_role";

grant select on table "public"."note_views" to "service_role";

grant trigger on table "public"."note_views" to "service_role";

grant truncate on table "public"."note_views" to "service_role";

grant update on table "public"."note_views" to "service_role";

grant delete on table "public"."notes" to "anon";

grant insert on table "public"."notes" to "anon";

grant references on table "public"."notes" to "anon";

grant select on table "public"."notes" to "anon";

grant trigger on table "public"."notes" to "anon";

grant truncate on table "public"."notes" to "anon";

grant update on table "public"."notes" to "anon";

grant delete on table "public"."notes" to "authenticated";

grant insert on table "public"."notes" to "authenticated";

grant references on table "public"."notes" to "authenticated";

grant select on table "public"."notes" to "authenticated";

grant trigger on table "public"."notes" to "authenticated";

grant truncate on table "public"."notes" to "authenticated";

grant update on table "public"."notes" to "authenticated";

grant delete on table "public"."notes" to "service_role";

grant insert on table "public"."notes" to "service_role";

grant references on table "public"."notes" to "service_role";

grant select on table "public"."notes" to "service_role";

grant trigger on table "public"."notes" to "service_role";

grant truncate on table "public"."notes" to "service_role";

grant update on table "public"."notes" to "service_role";

grant delete on table "public"."payout_transactions" to "anon";

grant insert on table "public"."payout_transactions" to "anon";

grant references on table "public"."payout_transactions" to "anon";

grant select on table "public"."payout_transactions" to "anon";

grant trigger on table "public"."payout_transactions" to "anon";

grant truncate on table "public"."payout_transactions" to "anon";

grant update on table "public"."payout_transactions" to "anon";

grant delete on table "public"."payout_transactions" to "authenticated";

grant insert on table "public"."payout_transactions" to "authenticated";

grant references on table "public"."payout_transactions" to "authenticated";

grant select on table "public"."payout_transactions" to "authenticated";

grant trigger on table "public"."payout_transactions" to "authenticated";

grant truncate on table "public"."payout_transactions" to "authenticated";

grant update on table "public"."payout_transactions" to "authenticated";

grant delete on table "public"."payout_transactions" to "service_role";

grant insert on table "public"."payout_transactions" to "service_role";

grant references on table "public"."payout_transactions" to "service_role";

grant select on table "public"."payout_transactions" to "service_role";

grant trigger on table "public"."payout_transactions" to "service_role";

grant truncate on table "public"."payout_transactions" to "service_role";

grant update on table "public"."payout_transactions" to "service_role";

grant delete on table "public"."post_votes" to "anon";

grant insert on table "public"."post_votes" to "anon";

grant references on table "public"."post_votes" to "anon";

grant select on table "public"."post_votes" to "anon";

grant trigger on table "public"."post_votes" to "anon";

grant truncate on table "public"."post_votes" to "anon";

grant update on table "public"."post_votes" to "anon";

grant delete on table "public"."post_votes" to "authenticated";

grant insert on table "public"."post_votes" to "authenticated";

grant references on table "public"."post_votes" to "authenticated";

grant select on table "public"."post_votes" to "authenticated";

grant trigger on table "public"."post_votes" to "authenticated";

grant truncate on table "public"."post_votes" to "authenticated";

grant update on table "public"."post_votes" to "authenticated";

grant delete on table "public"."post_votes" to "service_role";

grant insert on table "public"."post_votes" to "service_role";

grant references on table "public"."post_votes" to "service_role";

grant select on table "public"."post_votes" to "service_role";

grant trigger on table "public"."post_votes" to "service_role";

grant truncate on table "public"."post_votes" to "service_role";

grant update on table "public"."post_votes" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."saved_notes" to "anon";

grant insert on table "public"."saved_notes" to "anon";

grant references on table "public"."saved_notes" to "anon";

grant select on table "public"."saved_notes" to "anon";

grant trigger on table "public"."saved_notes" to "anon";

grant truncate on table "public"."saved_notes" to "anon";

grant update on table "public"."saved_notes" to "anon";

grant delete on table "public"."saved_notes" to "authenticated";

grant insert on table "public"."saved_notes" to "authenticated";

grant references on table "public"."saved_notes" to "authenticated";

grant select on table "public"."saved_notes" to "authenticated";

grant trigger on table "public"."saved_notes" to "authenticated";

grant truncate on table "public"."saved_notes" to "authenticated";

grant update on table "public"."saved_notes" to "authenticated";

grant delete on table "public"."saved_notes" to "service_role";

grant insert on table "public"."saved_notes" to "service_role";

grant references on table "public"."saved_notes" to "service_role";

grant select on table "public"."saved_notes" to "service_role";

grant trigger on table "public"."saved_notes" to "service_role";

grant truncate on table "public"."saved_notes" to "service_role";

grant update on table "public"."saved_notes" to "service_role";

create policy "Users can create events"
on "public"."events"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can create their own events"
on "public"."events"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can delete own events"
on "public"."events"
as permissive
for delete
to public
using ((auth.uid() = user_id));


create policy "Users can delete their own events"
on "public"."events"
as permissive
for delete
to public
using ((auth.uid() = user_id));


create policy "Users can update own events"
on "public"."events"
as permissive
for update
to public
using ((auth.uid() = user_id));


create policy "Users can update their own events"
on "public"."events"
as permissive
for update
to public
using ((auth.uid() = user_id));


create policy "Users can view their own events"
on "public"."events"
as permissive
for select
to public
using ((auth.uid() = user_id));


create policy "System can insert file access logs"
on "public"."file_access_logs"
as permissive
for insert
to public
with check ((auth.uid() IS NOT NULL));


create policy "Users can create file access logs"
on "public"."file_access_logs"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can view their own file access logs"
on "public"."file_access_logs"
as permissive
for select
to public
using ((auth.uid() = user_id));


create policy "Anyone can view followers"
on "public"."followers"
as permissive
for select
to public
using (true);


create policy "Users can follow others"
on "public"."followers"
as permissive
for insert
to public
with check ((auth.uid() = follower_id));


create policy "Users can unfollow others"
on "public"."followers"
as permissive
for delete
to public
using ((auth.uid() = follower_id));


create policy "Forum posts are viewable by everyone"
on "public"."forum_posts"
as permissive
for select
to public
using (true);


create policy "Users can create forum posts"
on "public"."forum_posts"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can delete own forum posts"
on "public"."forum_posts"
as permissive
for delete
to public
using ((auth.uid() = user_id));


create policy "Users can update own forum posts"
on "public"."forum_posts"
as permissive
for update
to public
using ((auth.uid() = user_id));


create policy "Forum replies are viewable by everyone"
on "public"."forum_replies"
as permissive
for select
to public
using (true);


create policy "Users can create forum replies"
on "public"."forum_replies"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can delete own forum replies"
on "public"."forum_replies"
as permissive
for delete
to public
using ((auth.uid() = user_id));


create policy "Users can update own forum replies"
on "public"."forum_replies"
as permissive
for update
to public
using ((auth.uid() = user_id));


create policy "Allow users read access for their likes"
on "public"."note_likes"
as permissive
for select
to public
using ((auth.uid() = user_id));


create policy "Allow users to manage their own likes"
on "public"."note_likes"
as permissive
for all
to public
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));


create policy "Users can delete likes for their own notes"
on "public"."note_likes"
as permissive
for delete
to authenticated
using ((auth.uid() = ( SELECT notes.user_id
   FROM notes
  WHERE (notes.id = note_likes.note_id))));


create policy "Allow users to insert their own view"
on "public"."note_views"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Allow users to read their own views"
on "public"."note_views"
as permissive
for select
to public
using ((auth.uid() = user_id));


create policy "Users can delete views for their own notes"
on "public"."note_views"
as permissive
for delete
to authenticated
using ((auth.uid() = ( SELECT notes.user_id
   FROM notes
  WHERE (notes.id = note_views.note_id))));


create policy "Allow authenticated users to insert their own notes"
on "public"."notes"
as permissive
for insert
to authenticated
with check ((auth.uid() = user_id));


create policy "Public notes are viewable by everyone"
on "public"."notes"
as permissive
for select
to public
using (((is_public = true) OR (auth.uid() = user_id)));


create policy "Users can delete their own notes"
on "public"."notes"
as permissive
for delete
to authenticated
using ((auth.uid() = user_id));


create policy "Users can insert their own notes"
on "public"."notes"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can update their own notes"
on "public"."notes"
as permissive
for update
to public
using ((auth.uid() = user_id));


create policy "Users can view their own notes"
on "public"."notes"
as permissive
for select
to authenticated
using ((auth.uid() = user_id));


create policy "Allow delete for users matching user_id"
on "public"."post_votes"
as permissive
for delete
to authenticated
using ((auth.uid() = user_id));


create policy "Allow insert for users matching user_id"
on "public"."post_votes"
as permissive
for insert
to authenticated
with check ((auth.uid() = user_id));


create policy "Allow read access to authenticated users"
on "public"."post_votes"
as permissive
for select
to authenticated
using (true);


create policy "Allow update for users matching user_id"
on "public"."post_votes"
as permissive
for update
to authenticated
using ((auth.uid() = user_id))
with check ((auth.uid() = user_id));


create policy "Allow authenticated users to view profiles"
on "public"."profiles"
as permissive
for select
to authenticated
using (true);


create policy "Allow profile creation via function"
on "public"."profiles"
as permissive
for insert
to public
with check ((current_setting('app.allow_profile_creation'::text, true) = 'true'::text));


create policy "Allow users to delete their own profile"
on "public"."profiles"
as permissive
for delete
to authenticated
using ((auth.uid() = id));


create policy "Allow users to update their own profile"
on "public"."profiles"
as permissive
for update
to authenticated
using ((auth.uid() = id))
with check ((auth.uid() = id));


create policy "Users can create their own profile."
on "public"."profiles"
as permissive
for insert
to authenticated
with check ((auth.uid() = id));


create policy "Users can insert their own profile."
on "public"."profiles"
as permissive
for insert
to authenticated
with check ((auth.uid() = id));


create policy "Users can update their own profile."
on "public"."profiles"
as permissive
for update
to public
using ((auth.uid() = id))
with check ((auth.uid() = id));


create policy "Users can delete saves for their own notes"
on "public"."saved_notes"
as permissive
for delete
to authenticated
using ((auth.uid() = ( SELECT notes.user_id
   FROM notes
  WHERE (notes.id = saved_notes.note_id))));


create policy "Users can save notes"
on "public"."saved_notes"
as permissive
for insert
to public
with check ((auth.uid() = user_id));


create policy "Users can unsave notes"
on "public"."saved_notes"
as permissive
for delete
to public
using ((auth.uid() = user_id));


create policy "Users can view their own saved notes"
on "public"."saved_notes"
as permissive
for select
to public
using ((auth.uid() = user_id));


CREATE TRIGGER on_follow_change AFTER INSERT OR DELETE ON public.followers FOR EACH ROW EXECUTE FUNCTION update_follower_counts();

CREATE TRIGGER on_like_change AFTER INSERT OR DELETE ON public.note_likes FOR EACH ROW EXECUTE FUNCTION update_note_like_count();

CREATE TRIGGER on_view_insert AFTER INSERT ON public.note_views FOR EACH ROW EXECUTE FUNCTION increment_note_view_count();

CREATE TRIGGER before_delete_note BEFORE DELETE ON public.notes FOR EACH ROW EXECUTE FUNCTION delete_note_likes();

CREATE TRIGGER before_delete_note_views BEFORE DELETE ON public.notes FOR EACH ROW EXECUTE FUNCTION delete_note_views();

CREATE TRIGGER before_delete_saved_notes BEFORE DELETE ON public.notes FOR EACH ROW EXECUTE FUNCTION delete_saved_notes();

CREATE TRIGGER on_note_deleted BEFORE DELETE ON public.notes FOR EACH ROW EXECUTE FUNCTION update_storage_on_note_delete();



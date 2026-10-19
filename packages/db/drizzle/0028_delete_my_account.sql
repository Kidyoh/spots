-- In-app account deletion (Google Play requires apps with accounts to offer it
-- inside the app). One SECURITY DEFINER call removes everything keyed by the
-- caller's auth.uid() and then the auth account itself, in one transaction —
-- if any step fails, nothing is deleted.
--
-- What goes:
--   dating_opt_in, likes (both directions), blocks (both directions) — these
--     also FK-cascade from profiles (0019), deleted explicitly so the order
--     never depends on that
--   saved_spots, visits (public ratings + notes), feedback, profiles
--   auth.users (auth.identities / sessions / refresh tokens cascade inside
--     the auth schema)
-- What's kept, anonymised:
--   events — user_id is cleared so the analytics stream keeps its counts but
--     nothing in it points at the person any more
--   admin attribution on spots / happenings / suppressed_places — cleared, so
--     the curated catalog stays but no longer names the account
--
-- No public table has an FK to auth.users (user ids are text), so deleting the
-- auth row last can't trip a constraint.

CREATE OR REPLACE FUNCTION public.delete_my_account() RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  uid uuid := (SELECT auth.uid());
  me text := uid::text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;

  -- matching (web)
  DELETE FROM public.dating_opt_in WHERE user_id = me;
  DELETE FROM public.likes WHERE from_user = me OR to_user = me;
  DELETE FROM public.blocks WHERE blocker = me OR blocked = me;

  -- personal lists and public reviews
  DELETE FROM public.saved_spots WHERE user_id = me;
  DELETE FROM public.visits WHERE user_id = me;
  DELETE FROM public.feedback WHERE user_id = me;

  -- analytics: keep the rows, drop the link to the account
  UPDATE public.events SET user_id = NULL WHERE user_id = me;

  -- admin attribution (only ever set for admins)
  UPDATE public.spots SET owner_id = NULL WHERE owner_id = me;
  UPDATE public.spots SET created_by = NULL WHERE created_by = me;
  UPDATE public.spots SET updated_by = NULL WHERE updated_by = me;
  UPDATE public.happenings SET reviewed_by = NULL WHERE reviewed_by = me;
  UPDATE public.suppressed_places SET created_by = NULL WHERE created_by = me;

  DELETE FROM public.profiles WHERE id = me;
  DELETE FROM auth.users WHERE id = uid;
END;
$$;
--> statement-breakpoint
-- Supabase's default privileges grant EXECUTE on new public functions to anon
-- directly, so revoking from PUBLIC alone isn't enough.
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

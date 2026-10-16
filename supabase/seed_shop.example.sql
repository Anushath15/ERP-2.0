-- Run ONCE in Supabase > SQL Editor, after 0001_sync.sql and after both owners have signed in with Google once
-- (Authentication > Users must list both addresses). Replace the two e-mails, then press Run.
with s as (insert into public.shops (name) values ('Senthil Enterprises') returning id)
insert into public.shop_members (shop_id, user_id, role)
select s.id, u.id, 'owner' from s, auth.users u
where u.email in ('OWNER1@gmail.com', 'OWNER2@gmail.com');

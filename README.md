# SkillWiz 2.0 website

Static one-page site. No build step.

- `index.html`: the whole site (styles, scripts and graphics inside).
- `supabase/schema.sql`: database tables and security rules. Run once in the Supabase SQL Editor.
- `supabase/SUPABASE_SETUP.md`: step-by-step Supabase setup.
- `vercel.json`: security headers for Vercel.

## Deploy on Vercel
1. Push this folder to a new GitHub repository.
2. In Vercel choose **Add New > Project**, import the repository.
3. Framework preset: **Other**. Leave build command and output directory empty. Deploy.

## Supabase
The public project URL and anon key are set near the top of the script in `index.html` (search for `SUPABASE_URL`). These two values are public by design. Never put the `service_role` key in this repository.

After the site has a web address, add it in Supabase under Authentication > URL Configuration (Site URL and Redirect URLs).

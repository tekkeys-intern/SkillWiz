# Connecting SkillWiz to Supabase

The site can now create accounts, log users in, record each login, and save every form submission to your own Supabase project. Until you add your keys it runs in preview mode and nothing is sent.

## 1. Create the project
1. Sign in at supabase.com and create a project (choose a region close to your users, for example Mumbai).
2. In **SQL Editor > New query**, paste all of `schema.sql` and press **Run**. It creates three tables (`profiles`, `login_events`, `leads`) with row-level security switched on.

## 2. Paste two values into the site
In **Project Settings > API** copy:
- **Project URL**
- **anon public key**

Open `index.html`, find the block marked `SUPABASE`, and paste them:

```js
const SUPABASE_URL="https://xxxxxxxx.supabase.co";
const SUPABASE_ANON_KEY="eyJ...";
```

The anon key is meant to be public; the policies in `schema.sql` are what protect your data.
**Never paste the `service_role` key into the website or share it in chat or email.** It bypasses every protection.

## 3. Set up sign-in
In **Authentication**:
- **URL Configuration**: set *Site URL* to your live address, and add it (and `http://localhost:8000` for testing) to *Redirect URLs*. Magic links and password resets fail without this.
- **Providers > Email**: keep *Confirm email* on, so only real addresses become accounts.
- **Attack Protection**: switch on CAPTCHA (hCaptcha or Turnstile) before launch to stop bot sign-ups. Tell me if you want it wired into the form.
- **Emails**: edit the confirmation and magic-link templates to carry SkillWiz branding. For volume, add your own SMTP (the built-in sender is rate-limited).

## 4. Make yourself an admin
1. Open the site, choose **Login > Create account**, and sign up with your own email.
2. Confirm the email, then in the SQL Editor run (with your address):
   ```sql
   update public.profiles set is_admin = true where email = 'you@yourcompany.com';
   ```

## 5. See your data
In the Supabase dashboard:
- **Table Editor**: `profiles` (every user), `login_events` (every login with time, role and browser), `leads` (every form).
- **SQL Editor**:
  ```sql
  select * from public.admin_user_overview();   -- users, last login, number of logins
  select * from public.login_events order by created_at desc limit 100;
  select source, count(*) from public.leads group by 1 order by 2 desc;
  ```
- **Authentication > Users** also shows last sign-in time. IP addresses are in **Logs > Auth**; the site itself does not collect them.

## What is saved
| Table | Written when | Contains |
|---|---|---|
| `profiles` | A user creates an account | name, email, role, organisation, phone, time of consent |
| `login_events` | A user logs in or signs up | user, email, role, time, browser, page |
| `leads` | Any form is submitted (visitors need not be logged in) | form name, the answers, page, user if logged in |

Passwords are handled by Supabase Auth and are never stored in your tables.

## Privacy notes (DPDP Act, 2023)
- Sign-up requires a consent tick, and the time is stored in `profiles.consented_at`.
- Add a privacy notice page and link it from the consent line before launch.
- Users can be deleted from **Authentication > Users**; their profile and login rows are removed with them.

## Roles on the site
Login menu choices map to: `student`, `faculty`, `tpo`, `leadership`, `recruiter`. A user can never choose `admin`; only the SQL line in step 4 can do that.

## Not yet done
- Social sign-in (Google) needs an OAuth client set up in Google and Supabase.
- Role-specific dashboards after login. Today a logged-in user sees their name and a log-out option, and the data is captured; dashboards are a separate build.
- I could not test against a live Supabase project from here. Run steps 1 to 4, then try one sign-up, one login and one form, and check the three tables.

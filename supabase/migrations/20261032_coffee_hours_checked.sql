-- Coffee places: hours checked on 13 October 2026 against each venue's own
-- website (and Google). Every place is open at the times we suggest it; these
-- are the corrections. One statement, so it runs the same however the SQL
-- editor runs it, and running it again changes nothing.
--
-- Soepp: from its website (it lists hours per date, so they may vary):
--   daytime every day; evenings Thursday to Sunday, until 22:00.
-- 1480 Foodbar: its hours are known now, open every evening.
-- Anne&Max: Saturday until 18:00, Sunday from 09:00.
-- Grand Café Klunder: on Mondays it closes at 18:00 unless Theater De Vest
--   has a show (no coffees are planned on Mondays anyway).
update public.circle_coffee_places p
   set opening_hours = v.hours::jsonb, hours_checked_at = date '2026-10-13'
  from (values
    ('Soepp', '{"mon": [{"open": "11:00", "close": "15:00"}],
                "tue": [{"open": "10:00", "close": "16:00"}],
                "wed": [{"open": "10:00", "close": "16:00"}],
                "thu": [{"open": "10:00", "close": "22:00"}],
                "fri": [{"open": "09:30", "close": "22:00"}],
                "sat": [{"open": "09:30", "close": "22:00"}],
                "sun": [{"open": "09:30", "close": "22:00"}]}'),
    ('1480 Foodbar', '{"mon": [{"open": "12:00", "close": "23:00"}],
                       "tue": [{"open": "11:00", "close": "23:00"}],
                       "wed": [{"open": "11:00", "close": "23:00"}],
                       "thu": [{"open": "11:00", "close": "23:00"}],
                       "fri": [{"open": "11:00", "close": "01:00"}],
                       "sat": [{"open": "12:00", "close": "01:00"}],
                       "sun": [{"open": "12:00", "close": "23:00"}]}'),
    ('Anne&Max', '{"mon": [{"open": "08:30", "close": "17:30"}],
                   "tue": [{"open": "08:30", "close": "17:30"}],
                   "wed": [{"open": "08:30", "close": "17:30"}],
                   "thu": [{"open": "08:30", "close": "17:30"}],
                   "fri": [{"open": "08:30", "close": "17:30"}],
                   "sat": [{"open": "08:30", "close": "18:00"}],
                   "sun": [{"open": "09:00", "close": "17:30"}]}'),
    ('Grand Café Klunder', '{"mon": [{"open": "09:00", "close": "18:00"}],
                             "tue": [{"open": "09:00", "close": "22:00"}],
                             "wed": [{"open": "09:00", "close": "22:00"}],
                             "thu": [{"open": "09:00", "close": "22:00"}],
                             "fri": [{"open": "09:00", "close": "22:00"}],
                             "sat": [{"open": "09:00", "close": "22:00"}],
                             "sun": [{"open": "11:00", "close": "22:00"}]}')
  ) v(name, hours)
 where p.city = 'Alkmaar' and p.name = v.name;

-- Fix: Captain America: Brave New World is Phase Five, not Phase Six.
-- Affects both films and film_details, since phase was loaded into each.

UPDATE films
SET phase = 'Phase Five'
WHERE title = 'Captain America: Brave New World';

UPDATE film_details
SET phase = 'Phase Five'
WHERE title = 'Captain America: Brave New World';

-- Verify the fix and check phase counts afterward
SELECT phase, COUNT(*) AS film_count
FROM films
GROUP BY phase
ORDER BY phase;

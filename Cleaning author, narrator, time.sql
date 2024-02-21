-- OVERALL CLEANING PROCESS FOR DATASET: rating
-- FORMAT:
	-- Cleaning Goal:
	-- Uncleaned: (Format)
	-- Cleaned: (Format)
	-- Explanation:
	--SQL QUERY
_______________________________________________________________________________________________________________________

-- Cleaning Goal: Stripping access texts from the author and narrator column leaving only their first and last name no spaces inbetween.
-- Uncleaned:
		-- author: 'Writtenby:GeronimoStilton'
		-- narrator: 'Narratedby:BillLobely'
-- Cleaned: 
		-- author: 'GeronimoStilton'
		-- narrator: 'BillLobely'			
-- Explanation: Since each author and narrator columns were text type and had the same uncleaned format and pattern, I decided to simply retrieve the wanted text which was everything to the right of the ':', therefore RIGHT() was my first thought only requireing the position of ':' and length of author/narrator
SELECT author,
		narrator,
		RIGHT(author, LENGTH(author) - STRPOS(author, ':')) as cleaned_author,
		RIGHT(narrator, LENGTH(narrator) - STRPOS(narrator, ':')) as cleaned_narrator	
FROM rating;

UPDATE rating
SET author = RIGHT(author, LENGTH(author) - STRPOS(author, ':')),
narrator = RIGHT(narrator, LENGTH(narrator) - STRPOS(narrator, ':'));

_______________________________________________________________________________________________________________________

-- Cleaning Goal: Turning a text of hrs and minutes into integer of total_minutes
-- Uncleaned: '2 hrs and 20 mins' | '10 hrs' | '22 mins'
-- Cleaned: '140' | '600' | '22'
-- Explanation: The first step was to separate hours and minutes in seperate columns and if NULL if a column did not have hrs or mins. Since the format varied from combinations of 'hr' to 'hrs' and 'min' to 'mins', I decided to utilize regexp_matches to locate the digit that corresponds to teh regex. Once it was seperated to hours and minutes column, I then utilized the COAlESCE() to easily calculate the total minutes which deals with the possible null values in each column. Then a simple type conversion to Integer once the calculations were done. I utilized a CTE to make the SELECT statement less cluttered and so I could solve the query one step at a time.

WITH time_split AS (
    SELECT 
        id, time,
      (regexp_matches(time, '(\d+) hr'))[1] AS hours,
        (regexp_matches(time, '(\d+) min'))[1] AS minutes
    FROM rating
)

SELECT R.id,
		COALESCE((hours::INTEGER * 60 + minutes::INTEGER), hours::INTEGER * 60, minutes::INTEGER) as total_minutes
FROM rating R
	JOIN time_split TS
	ON R.id = TS.id
ORDER BY R.id;

-- Converting hours to minutes and combining with minutes column for total minutes
	
UPDATE rating
SET time = (COALESCE((hours::INTEGER * 60 + minutes::INTEGER), hours::INTEGER * 60, minutes::INTEGER)
FROM (
    SELECT 
        id,
         (regexp_matches(time, '(\d+) hr'))[1] AS hours,
        (regexp_matches(time, '(\d+) min'))[1] AS minutes
    FROM rating
) AS TS
WHERE rating.id = TS.id);

ALTER TABLE rating
	RENAME COLUMN time TO total_minutes;
ALTER TABLE rating
	ALTER COLUMN total_minutes TYPE INTEGER
	USING total_minutes::INTEGER;

_______________________________________________________________________________________________________________________

-- Cleaning Goal: Proper Capitilization of column langauge
-- Uncleaned: 'japanese' 'English'
-- Cleaned: 'Japenese' 'English'
-- Explanation: A simple Query to capitilize the first letter and concat it with the rest of the text. If there were more uncleaned I would utilize the lower() for the substring.
SELECT id, CONCAT(UPPER(LEFT(language, 1)), SUBSTRING(language, 2, LENGTH(language) - 1)) as cap_language FROM rating;

UPDATE rating
SET language = CONCAT(UPPER(LEFT(language, 1)), SUBSTRING(language, 2, LENGTH(language) - 1));

_______________________________________________________________________________________________________________________

-- Cleaning Goal: Seperate stars column into two seperate columns of star rating and number of ratings
-- Uncleaned: '5 out of 5 stars1 rating' '3.3 out of 5stars11 ratings''Not rated yet'
-- Cleaned:
	-- stars: 5
	--rating_count: 1
-- Explanation: For text that were not 'Not rated yet' it followed a similar pattern where to get the stars a simple Substring and location of the first ' ' can retrieve the digit whether it be int or decimal. The rating(s) had to be extracted using regex_replace looking for a digit of any length followed by ' rating(s)' making sure the 's' is optional. For stars I kept it as text since 'Not rated yet' made sense to leave there and couuld not be converted to Number. Not rated yet != 0 stars. On the other hand the rating_count was changed to an integer.
SELECT id, stars,
	(CASE WHEN stars !~ 'Not rated yet' THEN SUBSTRING(stars, 1, STRPOS(stars,' ')) ELSE stars END) as star_rating,
	(CASE WHEN stars ~ '(\d+) out' THEN regexp_replace(stars, '.*?(\d+) rating[s]?\s*$', '\1') 								-- looks for any digit length that comes before ' rating(s)'
		 ELSE
		 '0'
		 END
	) as rating_count
FROM rating;

ALTER TABLE rating
ADD rating_count TEXT;

UPDATE rating
SET stars = CASE WHEN stars !~ 'Not rated yet' THEN SUBSTRING(stars, 1, STRPOS(stars,' ')) ELSE stars END,
rating_count = CASE WHEN stars ~ '(\d+) out' THEN regexp_replace(stars, '.*?(\d+) rating[s]?\s*$', '\1') ELSE '0' END

ALTER TABLE rating
	ALTER COLUMN rating_count TYPE INTEGER
	USING rating_count::integer;


_______________________________________________________________________________________________________________________
 
-- Cleaning Goal: Having each price column match up to a number type format.
-- Uncleaned: '1,201.50' 'Free' '900.00'
-- Cleaned: '1201.50' '0.00' '900.00'
-- Explanation: Another simple fix where in order to change a text to NUMBER(10,2), I had to convert Free to 0 and rid of any commas within the larger numbers.

SELECT price,
		(CASE WHEN price = 'Free' THEN '0.00'
		 ELSE REPLACE(price, ',', '')
		 END)
FROM rating

UPDATE rating
SET price = CASE WHEN price = 'Free' THEN '0.00'
		 ELSE REPLACE(price, ',', '')
		 END

ALTER TABLE rating
	ALTER COLUMN price TYPE NUMERIC(10,2)
	USING price::NUMERIC(10,2)
	 
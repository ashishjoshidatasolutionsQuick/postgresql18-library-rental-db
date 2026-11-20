CREATE SCHEMA Catalog;
CREATE SCHEMA Circulation;
CREATE TABLE catalog.authors
(
	author_id UUID PRIMARY KEY DEFAULT UUIDV7(),
	full_name VARCHAR (70) NOT NULL,
	country VARCHAR (90) NOT NULL,
	birth_year INT
);
CREATE TABLE catalog.books
(
	book_id UUID PRIMARY KEY DEFAULT UUIDV7(),
	author_id UUID REFERENCES catalog.authors(author_id),
	isbn VARCHAR(20) UNIQUE NOT NULL,
	title VARCHAR(150) NOT NULL,
	genre VARCHAR(50),
	total_copies INT CHECK (total_copies>=0),
	available_copies INT CHECK (available_copies>=0)
);
CREATE TABLE circulation.members
(
	member_id UUID PRIMARY KEY DEFAULT UUIDV7(),
	full_name VARCHAR (80) NOT NULL,
	email VARCHAR(100) NOT NULL UNIQUE,
	membership_type VARCHAR (40) CHECK (membership_type IN ('standard','student','premium')),
	joined_date DATE NOT NULL
);
CREATE TABLE circulation.loans
(
	loan_id UUID PRIMARY KEY DEFAULT UUIDV7(),
	book_id UUID REFERENCES catalog.books(booK_id) NOT NULL,
	member_id UUID REFERENCES circulation.members(member_id)NOT NULL,
	loan_date DATE  NOT NULL,
	due_date DATE NOT NULL,
	return_date DATE,
	fine_amount NUMERIC (8,2) DEFAULT 0.00
);

		ALTER TABLE circulation.loans
    DROP CONSTRAINT loans_book_id_fkey,
    DROP CONSTRAINT loans_member_id_fkey,
    ADD CONSTRAINT loans_book_id_fkey 
        FOREIGN KEY (book_id) REFERENCES catalog.books(book_id) ON DELETE RESTRICT,
    ADD CONSTRAINT loans_member_id_fkey 
        FOREIGN KEY (member_id) REFERENCES circulation.members(member_id) ON DELETE RESTRICT;

SELECT b.book_id,b.title,b.genre,b.available_copies,a.full_name AS author_name
FROM catalog.books b
INNER JOIN catalog.authors a ON b.author_id=a.author_id
WHERE b.genre IN('Fiction','Mystery')
AND b.available_copies >=3
ORDER BY b.genre,b.title;

SELECT l.loan_id,m.full_name AS member_name,m.email,b.title AS book_title,l.due_date,
		(CURRENT_DATE - l.due_date) AS days_overdue
FROM circulation.loans l
INNER JOIN circulation.members m ON l.member_id=m.member_id
INNER JOIN catalog.books b ON l.book_id=b.book_id
WHERE l.return_date IS NULL
AND l.due_date < CURRENT_DATE
ORDER BY days_overdue DESC;

SELECT b.genre,
	COUNT(l.loan_id) AS total_loans
FROM catalog.books b
INNER JOIN circulation.loans l ON b.book_id=l.book_id
GROUP BY b.genre
HAVING COUNT (l.loan_id)>15
ORDER BY total_loans DESC;

SELECT b.isbn,b.title,b.genre,b.total_copies
FROM catalog.books b
LEFT JOIN circulation.loans l ON b.book_id=l.book_id
WHERE l.loan_id IS NULL
ORDER BY b.title;

SELECT m.full_name, m.membership_type, COUNT(l.loan_id) AS No_of_fine,SUM(l.fine_amount) AS total_fine
FROM circulation.members m 
INNER JOIN circulation.loans l ON m.member_id=l.member_id
WHERE l.fine_amount>0
GROUP BY m.member_id,m.full_name,m.membership_type
ORDER BY total_fine DESC LIMIT 10;

SELECT loan_id, book_id, due_date, (CURRENT_DATE - due_date) AS days_overdue
FROM circulation.loans
WHERE return_date IS NULL
  AND due_date < CURRENT_DATE
LIMIT 1;
WITH returned_loan AS 
(
UPDATE circulation.loans
SET return_date=current_date,
fine_amount=(current_date-due_date)*15
WHERE loan_id='01a1704c-d31d-730a-900a-44fb9ef2b93e'
AND return_date IS NULL
RETURNING book_id
)
UPDATE catalog.books b
SET available_copies = b.available_copies + 1
FROM returned_loan rl
WHERE b.book_id = rl.book_id
RETURNING b.book_id, b.title, b.available_copies, b.total_copies;

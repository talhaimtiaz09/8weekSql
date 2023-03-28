-- drop table menu,members,sales
CREATE TABLE menu (
  product_id INTEGER primary key,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  customer_id VARCHAR(1) primary key,
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-08'),
  ('C', '2021-01-09');
  
 
CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER,
  foreign key(customer_id) references members(customer_id),
  foreign key(product_id) references menu(product_id)
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 
-- Question no 1 
------------------------------------------------------------------
-- What is the total amount each customer spent at the restaurant?

SELECT S.CUSTOMER_ID,
	SUM(M.PRICE) AS "Amount spent"
FROM SALES S,
	MENU M
WHERE S.PRODUCT_ID = M.PRODUCT_ID
GROUP BY S.CUSTOMER_ID ;
------------------------------------------------------------------
-- How many days has each customer visited the restaurant?

SELECT CUSTOMER_ID,
	COUNT(DISTINCT ORDER_DATE) AS "No of days visited"
FROM SALES
GROUP BY CUSTOMER_ID;

------------------------------------------------------------------
-- What was the first item from the menu purchased by each customer? (could be done better using rank() over())

SELECT DISTINCT ON(S.CUSTOMER_ID) S.CUSTOMER_ID,
	PRODUCT_NAME
FROM SALES S
JOIN MENU M ON S.PRODUCT_ID = M.PRODUCT_ID
WHERE S.ORDER_DATE in
		(SELECT MIN(ORDER_DATE)
			FROM SALES
			GROUP BY CUSTOMER_ID);

------------------------------------------------------------------
-- What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH SBQ AS
	(SELECT M.PRODUCT_NAME AS NAME,
			COUNT(S.PRODUCT_ID) AS COUNT
		FROM SALES S
		JOIN MENU M ON S.PRODUCT_ID = M.PRODUCT_ID
		GROUP BY S.PRODUCT_ID,
			M.PRODUCT_NAME)
SELECT NAME,
	COUNT AS "No of times sold"
FROM SBQ
WHERE COUNT =
		(SELECT MAX(COUNT)
			FROM SBQ) ;

------------------------------------------------------------------
-- Which item was the most popular for each customer?
WITH T AS
	(SELECT CUSTOMER_ID,
			PRODUCT_ID,
			COUNT(*),
			DENSE_RANK() 
	 		OVER(
		 		PARTITION BY CUSTOMER_ID
				ORDER BY COUNT(*) DESC
		    ) AS RNK
		FROM SALES S
		GROUP BY CUSTOMER_ID,
			PRODUCT_ID
		ORDER BY CUSTOMER_ID)
SELECT T.CUSTOMER_ID,
	M.PRODUCT_NAME
FROM T
JOIN MENU M ON T.PRODUCT_ID = M.PRODUCT_ID
WHERE T.RNK = 1 
------------------------------------------------------------------
-- Which item was purchased first by the customer after they became a member?
WITH T AS
	(SELECT S.CUSTOMER_ID AS CID,
			S.PRODUCT_ID AS PID,
			DENSE_RANK() 
	 		OVER(PARTITION BY S.CUSTOMER_ID
				ORDER BY S.ORDER_DATE
				) AS RNK
		FROM SALES S
		JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID
		WHERE S.ORDER_DATE >= M.JOIN_DATE)
SELECT T.CID,
	M.PRODUCT_NAME
FROM T
JOIN MENU M ON T.PID = M.PRODUCT_ID
WHERE RNK = 1 
------------------------------------------------------------------
-- Which item was purchased just before the customer became a member?
WITH T AS
		(SELECT S.CUSTOMER_ID AS CID,
				S.PRODUCT_ID AS PID,
				DENSE_RANK() 
		 		OVER(PARTITION BY S.CUSTOMER_ID
			    ORDER BY S.ORDER_DATE DESC) AS RNK
			FROM SALES S
			JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID
			WHERE S.ORDER_DATE < M.JOIN_DATE)
	SELECT T.CID,
		M.PRODUCT_NAME
	FROM T
	JOIN MENU M ON T.PID = M.PRODUCT_ID WHERE RNK = 1 
------------------------------------------------------------------
-- What is the total items and amount spent for each member before they became a member?
WITH T AS
		(SELECT S.CUSTOMER_ID AS CID,
				S.PRODUCT_ID AS PID
			FROM SALES S
			JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID
			WHERE S.ORDER_DATE < M.JOIN_DATE )
	SELECT T.CID,
		COUNT(CID) AS TOTAL_ITEMS,
		SUM(M.PRICE)AS TOTAL_SPENDING
	FROM T
	JOIN MENU M ON M.PRODUCT_ID = T.PID
GROUP BY T.CID
ORDER BY T.CID
------------------------------------------------------------------
-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT T.CUSTOMER_ID,
	COUNT(T.CUSTOMER_ID) AS TOTAL_ITEMS,
	SUM(
		CASE
		WHEN T.PRODUCT_ID = 1 THEN M.PRICE * 10 * 2
		ELSE M.PRICE * 10
		END
	)AS TOTAL_SPENDING
FROM SALES T
JOIN MENU M ON M.PRODUCT_ID = T.PRODUCT_ID
GROUP BY T.CUSTOMER_ID
ORDER BY T.CUSTOMER_ID
------------------------------------------------------------------
--(incomplete) In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH T AS
	(SELECT S.CUSTOMER_ID AS CID,
			S.PRODUCT_ID AS PID,
			S.ORDER_DATE,
			M.JOIN_DATE
		FROM SALES S
		JOIN MEMBERS M ON S.CUSTOMER_ID = M.CUSTOMER_ID
		WHERE S.ORDER_DATE >= M.JOIN_DATE )
SELECT T.CID,
	COUNT(CID) AS TOTAL_ITEMS,
	SUM(
		CASE
		WHEN T.ORDER_DATE <= T.JOIN_DATE + 7 THEN M.PRICE * 2 * 10
		WHEN T.ORDER_DATE >= T.JOIN_DATE + 7
		AND T.ORDER_DATE <= '2021-01-31'THEN (
			CASE
			WHEN T.PID = 1 THEN M.PRICE * 10 * 2
			ELSE M.PRICE * 10
			END
			)
		END
	)AS TOTAL_SPENDING
FROM T
JOIN MENU M ON M.PRODUCT_ID = T.PID
GROUP BY T.CID
ORDER BY T.CID
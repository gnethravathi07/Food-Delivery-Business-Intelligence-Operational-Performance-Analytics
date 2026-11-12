CREATE DATABASE FoodDelivery_Analytics;


USE FoodDelivery_Analytics;
GO

SELECT
    s.name AS Schema_Name,
    t.name AS Table_Name,
    SUM(p.rows) AS Total_Rows
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY t.name;



SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME, ORDINAL_POSITION;




-- 1. Duplicate order IDs
SELECT order_id, COUNT(*) AS Duplicate_Count
FROM dbo.fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 2. Duplicate date IDs
SELECT date_id, COUNT(*) AS Duplicate_Count
FROM dbo.dim_date
GROUP BY date_id
HAVING COUNT(*) > 1;

-- 3. Duplicate dish IDs
SELECT dish_id, COUNT(*) AS Duplicate_Count
FROM dbo.dim_dish
GROUP BY dish_id
HAVING COUNT(*) > 1;

-- 4. Duplicate location IDs
SELECT location_id, COUNT(*) AS Duplicate_Count
FROM dbo.dim_location
GROUP BY location_id
HAVING COUNT(*) > 1;

-- 5. Duplicate restaurant IDs
SELECT restaurant_id, COUNT(*) AS Duplicate_Count
FROM dbo.dim_restaurant
GROUP BY restaurant_id
HAVING COUNT(*) > 1;




SELECT
    'fact_orders' AS Table_Name,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS Null_Order_ID,
    SUM(CASE WHEN date_id IS NULL THEN 1 ELSE 0 END) AS Null_Date_ID,
    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) AS Null_Location_ID,
    SUM(CASE WHEN restaurant_id IS NULL THEN 1 ELSE 0 END) AS Null_Restaurant_ID,
    SUM(CASE WHEN food_id IS NULL THEN 1 ELSE 0 END) AS Null_Food_ID,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS Null_Price,
    SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS Null_Rating,
    SUM(CASE WHEN rating_count IS NULL THEN 1 ELSE 0 END) AS Null_Rating_Count
FROM dbo.fact_orders;




SELECT
    'dim_date' AS Table_Name,
    SUM(CASE WHEN date_id IS NULL THEN 1 ELSE 0 END) AS Null_Key,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS Null_Attribute
FROM dbo.dim_date

UNION ALL

SELECT
    'dim_dish',
    SUM(CASE WHEN dish_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN category IS NULL OR dish_name IS NULL THEN 1 ELSE 0 END)
FROM dbo.dim_dish

UNION ALL

SELECT
    'dim_location',
    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN state IS NULL OR city IS NULL OR location IS NULL THEN 1 ELSE 0 END)
FROM dbo.dim_location

UNION ALL

SELECT
    'dim_restaurant',
    SUM(CASE WHEN restaurant_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN restaurant_name IS NULL THEN 1 ELSE 0 END)
FROM dbo.dim_restaurant;



-- 1. Date references
SELECT COUNT(*) AS Invalid_Date_References
FROM dbo.fact_orders f
LEFT JOIN dbo.dim_date d
    ON f.date_id = d.date_id
WHERE d.date_id IS NULL;

-- 2. Dish references
SELECT COUNT(*) AS Invalid_Dish_References
FROM dbo.fact_orders f
LEFT JOIN dbo.dim_dish d
    ON f.food_id = d.dish_id
WHERE d.dish_id IS NULL;

-- 3. Location references
SELECT COUNT(*) AS Invalid_Location_References
FROM dbo.fact_orders f
LEFT JOIN dbo.dim_location l
    ON f.location_id = l.location_id
WHERE l.location_id IS NULL;

-- 4. Restaurant references
SELECT COUNT(*) AS Invalid_Restaurant_References
FROM dbo.fact_orders f
LEFT JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id
WHERE r.restaurant_id IS NULL;




-- 1. Invalid or zero prices
SELECT COUNT(*) AS Invalid_Price_Count
FROM dbo.fact_orders
WHERE price <= 0;

-- 2. Ratings outside the expected 1–5 range
SELECT COUNT(*) AS Invalid_Rating_Count
FROM dbo.fact_orders
WHERE rating < 1 OR rating > 5;

-- 3. Negative rating counts
SELECT COUNT(*) AS Invalid_Rating_Count_Values
FROM dbo.fact_orders
WHERE rating_count < 0;

-- 4. Negative prices
SELECT COUNT(*) AS Negative_Price_Count
FROM dbo.fact_orders
WHERE price < 0;




SELECT
    COUNT(*) AS Total_Date_Records,
    COUNT(DISTINCT date_id) AS Unique_Date_IDs,
    COUNT(DISTINCT order_date) AS Unique_Order_Dates,
    MIN(order_date) AS First_Date,
    MAX(order_date) AS Last_Date,
    DATEDIFF(DAY, MIN(order_date), MAX(order_date)) + 1
        AS Expected_Calendar_Days,
    COUNT(*) - COUNT(DISTINCT order_date)
        AS Duplicate_Dates
FROM dbo.dim_date;



SELECT
    COUNT(*) AS Total_Orders,
    COUNT(DISTINCT f.date_id) AS Distinct_Date_IDs,
    MIN(d.order_date) AS First_Order_Date,
    MAX(d.order_date) AS Last_Order_Date,
    COUNT(CASE WHEN d.order_date IS NULL THEN 1 END)
        AS Invalid_Date_Records
FROM dbo.fact_orders AS f
LEFT JOIN dbo.dim_date AS d
    ON f.date_id = d.date_id;




WITH Date_Range AS
(
    SELECT
        MIN(order_date) AS First_Date,
        MAX(order_date) AS Last_Date
    FROM dbo.dim_date
),
Expected_Dates AS
(
    SELECT First_Date AS Expected_Date
    FROM Date_Range

    UNION ALL

    SELECT DATEADD(DAY, 1, Expected_Date)
    FROM Expected_Dates
    CROSS JOIN Date_Range
    WHERE Expected_Date < Last_Date
)
SELECT
    COUNT(*) AS Missing_Date_Count
FROM Expected_Dates e
LEFT JOIN dbo.dim_date d
    ON e.Expected_Date = d.order_date
WHERE d.order_date IS NULL
OPTION (MAXRECURSION 0);




USE FoodDelivery_Analytics;
GO

-- 1. Dish dimension overview
SELECT
    COUNT(*) AS Total_Dishes,
    COUNT(DISTINCT dish_id) AS Unique_Dish_IDs,
    COUNT(DISTINCT dish_name) AS Unique_Dish_Names,
    COUNT(DISTINCT category) AS Total_Categories
FROM dbo.dim_dish;

-- 2. Dish category distribution
SELECT
    category,
    COUNT(*) AS Dish_Count
FROM dbo.dim_dish
GROUP BY category
ORDER BY Dish_Count DESC;

-- 3. Duplicate dish names
SELECT
    dish_name,
    COUNT(*) AS Name_Count
FROM dbo.dim_dish
GROUP BY dish_name
HAVING COUNT(*) > 1
ORDER BY Name_Count DESC;



-- 1. Dish dimension overview
SELECT
    COUNT(*) AS Total_Dishes,
    COUNT(DISTINCT dish_id) AS Unique_Dish_IDs,
    COUNT(DISTINCT dish_name) AS Unique_Dish_Names,
    COUNT(DISTINCT category) AS Total_Categories
FROM dbo.dim_dish;

-- 2. Dish category distribution
SELECT
    category,
    COUNT(*) AS Dish_Count
FROM dbo.dim_dish
GROUP BY category
ORDER BY Dish_Count DESC;

-- 3. Duplicate dish names
SELECT
    dish_name,
    COUNT(*) AS Name_Count
FROM dbo.dim_dish
GROUP BY dish_name
HAVING COUNT(*) > 1
ORDER BY Name_Count DESC;



SELECT TOP 20
    category,
    COUNT(*) AS Dish_Count
FROM dbo.dim_dish
GROUP BY category
ORDER BY Dish_Count DESC;



SELECT
    COUNT(*) AS Categories_With_Extra_Spaces
FROM dbo.dim_dish
WHERE category <> LTRIM(RTRIM(category));



SELECT
    category,
    LEN(category) AS Category_Length,
    COUNT(*) AS Dish_Count
FROM dbo.dim_dish
GROUP BY category
ORDER BY category;


SELECT TOP 50
    dish_id,
    category,
    dish_name
FROM dbo.dim_dish
ORDER BY dish_id;



SELECT
    category,
    dish_name,
    COUNT(*) AS Record_Count
FROM dbo.dim_dish
GROUP BY category, dish_name
ORDER BY category, dish_name;



-- =====================================================
-- STEP 19: DISH CATEGORY FREQUENCY PROFILING
-- =====================================================

WITH Category_Frequency AS
(
    SELECT
        category,
        COUNT(*) AS Dish_Count
    FROM dbo.dim_dish
    GROUP BY category
)
SELECT
    COUNT(*) AS Total_Distinct_Categories,
    SUM(CASE WHEN Dish_Count = 1 THEN 1 ELSE 0 END)
        AS Single_Record_Categories,
    SUM(CASE WHEN Dish_Count > 1 THEN 1 ELSE 0 END)
        AS Repeated_Categories,
    MAX(Dish_Count) AS Maximum_Dishes_In_Category,
    AVG(CAST(Dish_Count AS DECIMAL(10,2)))
        AS Average_Dishes_Per_Category
FROM Category_Frequency;




-- =====================================================
-- STEP 20.1: RESTAURANT DIMENSION OVERVIEW
-- =====================================================


SELECT
    COUNT(*) AS Total_Restaurants,
    COUNT(DISTINCT restaurant_id) AS Unique_Restaurant_IDs,
    COUNT(DISTINCT restaurant_name) AS Unique_Restaurant_Names
FROM dbo.dim_restaurant;


-- =====================================================
-- STEP 20.2: DUPLICATE RESTAURANT NAME ANALYSIS
-- =====================================================

SELECT
    restaurant_name,
    COUNT(*) AS Name_Count
FROM dbo.dim_restaurant
GROUP BY restaurant_name
HAVING COUNT(*) > 1
ORDER BY Name_Count DESC, restaurant_name;



-- =====================================================
-- STEP 20.3: RESTAURANT NAME FREQUENCY ANALYSIS
-- =====================================================

SELECT TOP 20
    restaurant_name,
    COUNT(*) AS Restaurant_Count
FROM dbo.dim_restaurant
GROUP BY restaurant_name
ORDER BY Restaurant_Count DESC, restaurant_name;




-- =====================================================
-- STEP 21.1: LOCATION DIMENSION OVERVIEW
-- =====================================================

USE FoodDelivery_Analytics;
GO

SELECT
    COUNT(*) AS Total_Location_Records,
    COUNT(DISTINCT location_id) AS Unique_Location_IDs,
    COUNT(DISTINCT state) AS Total_States,
    COUNT(DISTINCT city) AS Total_Cities,
    COUNT(DISTINCT location) AS Unique_Location_Names
FROM dbo.dim_location;



-- =====================================================
-- STEP 21.2: LOCATION DISTRIBUTION BY STATE
-- =====================================================

SELECT
    state,
    COUNT(*) AS Location_Count,
    COUNT(DISTINCT city) AS City_Count
FROM dbo.dim_location
GROUP BY state
ORDER BY Location_Count DESC;



-- =====================================================
-- STEP 21.3: CITY LOCATION DISTRIBUTION
-- =====================================================

SELECT TOP 20
    city,
    state,
    COUNT(*) AS Location_Count
FROM dbo.dim_location
GROUP BY city, state
ORDER BY Location_Count DESC, city;




-- =====================================================
-- STEP 22.1: DUPLICATE LOCATION NAME ANALYSIS
-- =====================================================

SELECT
    location,
    COUNT(*) AS Location_Count,
    COUNT(DISTINCT city) AS City_Count,
    COUNT(DISTINCT state) AS State_Count
FROM dbo.dim_location
GROUP BY location
HAVING COUNT(*) > 1
ORDER BY Location_Count DESC, location;




-- =====================================================
-- STEP 22.2: DUPLICATE CITY-STATE ANALYSIS
-- =====================================================

SELECT
    city,
    state,
    COUNT(*) AS Record_Count
FROM dbo.dim_location
GROUP BY city, state
HAVING COUNT(*) > 1
ORDER BY Record_Count DESC, city;




-- =====================================================
-- STEP 23: REPEATED LOCATION NAME DETAIL ANALYSIS
-- =====================================================


SELECT
    location_id,
    location,
    city,
    state
FROM dbo.dim_location
WHERE location IN
(
    SELECT location
    FROM dbo.dim_location
    GROUP BY location
    HAVING COUNT(*) > 1
)
ORDER BY location, state, city;



-- =====================================================
-- STEP 24: CASE-INSENSITIVE LOCATION DUPLICATE ANALYSIS
-- =====================================================


SELECT
    UPPER(LTRIM(RTRIM(location))) AS Normalized_Location,
    city,
    state,
    COUNT(*) AS Record_Count,
    COUNT(DISTINCT location_id) AS Unique_Location_IDs
FROM dbo.dim_location
GROUP BY
    UPPER(LTRIM(RTRIM(location))),
    city,
    state
HAVING COUNT(*) > 1
ORDER BY Record_Count DESC, Normalized_Location;



-- =====================================================
-- STEP 25: LOCATION DUPLICATION SUMMARY
-- =====================================================

WITH Location_Groups AS
(
    SELECT
        UPPER(LTRIM(RTRIM(location))) AS Normalized_Location,
        UPPER(LTRIM(RTRIM(city))) AS Normalized_City,
        UPPER(LTRIM(RTRIM(state))) AS Normalized_State,
        COUNT(*) AS Record_Count
    FROM dbo.dim_location
    GROUP BY
        UPPER(LTRIM(RTRIM(location))),
        UPPER(LTRIM(RTRIM(city))),
        UPPER(LTRIM(RTRIM(state)))
)
SELECT
    COUNT(*) AS Total_Duplicate_Groups,
    SUM(Record_Count) AS Records_In_Duplicate_Groups,
    SUM(Record_Count - 1) AS Excess_Duplicate_Records,
    MAX(Record_Count) AS Maximum_Records_Per_Group
FROM Location_Groups
WHERE Record_Count > 1;




-- =====================================================
-- STEP 26.1: FACT AND DIMENSION JOIN VALIDATION
-- =====================================================


SELECT
    COUNT(*) AS Joined_Order_Count,
    COUNT(DISTINCT f.order_id) AS Unique_Order_Count,
    COUNT(DISTINCT d.date_id) AS Matched_Date_IDs,
    COUNT(DISTINCT fd.dish_id) AS Matched_Dish_IDs,
    COUNT(DISTINCT l.location_id) AS Matched_Location_IDs,
    COUNT(DISTINCT r.restaurant_id) AS Matched_Restaurant_IDs
FROM dbo.fact_orders f
INNER JOIN dbo.dim_date d
    ON f.date_id = d.date_id
INNER JOIN dbo.dim_dish fd
    ON f.food_id = fd.dish_id
INNER JOIN dbo.dim_location l
    ON f.location_id = l.location_id
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id;





-- =====================================================
-- STEP 26.2: FACT VS JOINED ROW COUNT RECONCILIATION
-- =====================================================

SELECT
    (SELECT COUNT(*) FROM dbo.fact_orders)
        AS Original_Fact_Rows,
    COUNT(*) AS Joined_Rows,
    COUNT(*) - (SELECT COUNT(*) FROM dbo.fact_orders)
        AS Row_Count_Difference
FROM dbo.fact_orders f
INNER JOIN dbo.dim_date d
    ON f.date_id = d.date_id
INNER JOIN dbo.dim_dish fd
    ON f.food_id = fd.dish_id
INNER JOIN dbo.dim_location l
    ON f.location_id = l.location_id
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id;




-- =====================================================
-- STEP 27.1: OVERALL BUSINESS PERFORMANCE KPIs
-- =====================================================

SELECT
    COUNT(*) AS Total_Orders,
    COUNT(DISTINCT restaurant_id) AS Total_Restaurants,
    COUNT(DISTINCT food_id) AS Total_Dishes,
    COUNT(DISTINCT location_id) AS Total_Locations,

    SUM(price) AS Total_Revenue,

    AVG(price) AS Average_Order_Value,

    MIN(price) AS Minimum_Order_Price,

    MAX(price) AS Maximum_Order_Price,

    AVG(rating) AS Average_Rating,

    SUM(rating_count) AS Total_Rating_Count

FROM dbo.fact_orders;



-- =====================================================
-- STEP 27.2: BUSINESS PERFORMANCE BY RESTAURANT
-- =====================================================

SELECT
    COUNT(DISTINCT f.restaurant_id) AS Total_Restaurants,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Order_Value,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id;




-- =====================================================
-- STEP 28.1: MONTHLY REVENUE AND ORDER TREND ANALYSIS
-- =====================================================

SELECT
    YEAR(d.order_date) AS Order_Year,
    MONTH(d.order_date) AS Order_Month,
    DATENAME(MONTH, d.order_date) AS Month_Name,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Order_Value,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_date d
    ON f.date_id = d.date_id
GROUP BY
    YEAR(d.order_date),
    MONTH(d.order_date),
    DATENAME(MONTH, d.order_date)
ORDER BY
    Order_Year,
    Order_Month;



-- =====================================================
-- STEP 28.2: MONTH-OVER-MONTH REVENUE GROWTH
-- =====================================================

WITH Monthly_Revenue AS
(
    SELECT
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    GROUP BY
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Revenue_Growth AS
(
    SELECT
        Order_Year,
        Order_Month,
        Total_Revenue,
        LAG(Total_Revenue) OVER (
            ORDER BY Order_Year, Order_Month
        ) AS Previous_Month_Revenue
    FROM Monthly_Revenue
)
SELECT
    Order_Year,
    Order_Month,
    Total_Revenue,
    Previous_Month_Revenue,
    Total_Revenue - Previous_Month_Revenue AS Revenue_Change,
    CAST(
        (Total_Revenue - Previous_Month_Revenue)
        * 100.0 / NULLIF(Previous_Month_Revenue, 0)
        AS DECIMAL(10,2)
    ) AS MoM_Growth_Percentage
FROM Revenue_Growth
ORDER BY Order_Year, Order_Month;




-- =====================================================
-- STEP 29.1: RESTAURANT REVENUE RANKING
-- =====================================================


WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.price) AS Average_Order_Value
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    Average_Order_Value,
    RANK() OVER (
        ORDER BY Total_Revenue DESC
    ) AS Revenue_Rank,
    CAST(
        Total_Revenue * 100.0 /
        SUM(Total_Revenue) OVER ()
        AS DECIMAL(10,2)
    ) AS Revenue_Contribution_Percentage
FROM Restaurant_Revenue
ORDER BY Total_Revenue DESC;




-- =====================================================
-- STEP 29.2: TOP 20 RESTAURANTS BY REVENUE
-- =====================================================

SELECT TOP 20
    r.restaurant_id,
    r.restaurant_name,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Order_Value,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id
GROUP BY
    r.restaurant_id,
    r.restaurant_name
ORDER BY Total_Revenue DESC;




-- =====================================================
-- STEP 30.1: TOP 10 DISHES BY REVENUE
-- =====================================================

SELECT TOP 10
    d.dish_id,
    d.dish_name,
    d.category,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Price,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_dish d
    ON f.food_id = d.dish_id
GROUP BY
    d.dish_id,
    d.dish_name,
    d.category
ORDER BY Total_Revenue DESC;



-- =====================================================
-- STEP 30.2: DISH CATEGORY REVENUE ANALYSIS
-- =====================================================

SELECT
    d.category,
    COUNT(*) AS Total_Orders,
    COUNT(DISTINCT d.dish_id) AS Unique_Dishes,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Price,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_dish d
    ON f.food_id = d.dish_id
GROUP BY d.category
ORDER BY Total_Revenue DESC;




-- =====================================================
-- STEP 31.1: CITY-WISE REVENUE PERFORMANCE
-- =====================================================

SELECT
    l.city,
    l.state,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Order_Value,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_location l
    ON f.location_id = l.location_id
GROUP BY
    l.city,
    l.state
ORDER BY Total_Revenue DESC;



-- =====================================================
-- STEP 31.2: STATE-WISE REVENUE PERFORMANCE
-- =====================================================

SELECT
    l.state,
    COUNT(*) AS Total_Orders,
    COUNT(DISTINCT l.city) AS Total_Cities,
    SUM(f.price) AS Total_Revenue,
    AVG(f.price) AS Average_Order_Value,
    AVG(f.rating) AS Average_Rating
FROM dbo.fact_orders f
INNER JOIN dbo.dim_location l
    ON f.location_id = l.location_id
GROUP BY l.state
ORDER BY Total_Revenue DESC;




-- =====================================================
-- STEP 31.3: TOP 10 CITIES BY ORDER VOLUME
-- =====================================================

SELECT TOP 10
    l.city,
    l.state,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue
FROM dbo.fact_orders f
INNER JOIN dbo.dim_location l
    ON f.location_id = l.location_id
GROUP BY
    l.city,
    l.state
ORDER BY Total_Orders DESC;




-- =====================================================
-- STEP 32.1: RESTAURANT REVENUE PERFORMANCE CLASSIFICATION
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.price) AS Average_Order_Value
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    Average_Order_Value,
    CASE
        WHEN Total_Revenue >= 500000 THEN 'High Performer'
        WHEN Total_Revenue >= 100000 THEN 'Medium Performer'
        ELSE 'Low Performer'
    END AS Performance_Category
FROM Restaurant_Revenue
ORDER BY Total_Revenue DESC;


-- =====================================================
-- STEP 32.2: RESTAURANT PERFORMANCE CATEGORY SUMMARY.
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Classified_Restaurants AS
(
    SELECT
        CASE
            WHEN Total_Revenue >= 500000 THEN 'High Performer'
            WHEN Total_Revenue >= 100000 THEN 'Medium Performer'
            ELSE 'Low Performer'
        END AS Performance_Category,
        Total_Revenue
    FROM Restaurant_Revenue
)
SELECT
    Performance_Category,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Revenue) AS Total_Revenue,
    AVG(Total_Revenue) AS Average_Restaurant_Revenue
FROM Classified_Restaurants
GROUP BY Performance_Category
ORDER BY Total_Revenue DESC;




-- =====================================================
-- STEP 33.1: RESTAURANT RATING OVERVIEW
-- =====================================================


SELECT
    COUNT(DISTINCT restaurant_id) AS Total_Restaurants,
    AVG(rating) AS Overall_Average_Rating,
    MIN(rating) AS Minimum_Rating,
    MAX(rating) AS Maximum_Rating,
    SUM(rating_count) AS Total_Rating_Count,
    AVG(CAST(rating_count AS DECIMAL(18,2)))
        AS Average_Rating_Count
FROM dbo.fact_orders;



-- =====================================================
-- STEP 33.2: RESTAURANT-WISE RATING ANALYSIS
-- =====================================================

SELECT
    r.restaurant_id,
    r.restaurant_name,
    COUNT(*) AS Total_Orders,
    AVG(f.rating) AS Average_Rating,
    SUM(f.rating_count) AS Total_Rating_Count,
    AVG(CAST(f.rating_count AS DECIMAL(18,2)))
        AS Average_Rating_Count
FROM dbo.fact_orders f
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id
GROUP BY
    r.restaurant_id,
    r.restaurant_name
ORDER BY Average_Rating DESC;



-- =====================================================
-- STEP 33.3: TOP 20 HIGHEST-RATED RESTAURANTS
-- =====================================================

SELECT TOP 20
    r.restaurant_id,
    r.restaurant_name,
    COUNT(*) AS Total_Orders,
    AVG(f.rating) AS Average_Rating,
    SUM(f.rating_count) AS Total_Rating_Count
FROM dbo.fact_orders f
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id
GROUP BY
    r.restaurant_id,
    r.restaurant_name
ORDER BY
    Average_Rating DESC,
    Total_Rating_Count DESC;



-- =====================================================
-- STEP 34.1: RESTAURANT RATING CLASSIFICATION
-- =====================================================

WITH Restaurant_Ratings AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Average_Rating,
    CASE
        WHEN Average_Rating >= 4.5 THEN 'Excellent'
        WHEN Average_Rating >= 4.0 THEN 'Good'
        ELSE 'Needs Improvement'
    END AS Rating_Category
FROM Restaurant_Ratings
ORDER BY Average_Rating DESC;




-- =====================================================
-- STEP 34.2: RESTAURANT RATING CATEGORY SUMMARY
-- =====================================================

WITH Restaurant_Ratings AS
(
    SELECT
        r.restaurant_id,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Classified_Restaurants AS
(
    SELECT
        CASE
            WHEN Average_Rating >= 4.5 THEN 'Excellent'
            WHEN Average_Rating >= 4.0 THEN 'Good'
            ELSE 'Needs Improvement'
        END AS Rating_Category
    FROM Restaurant_Ratings
)
SELECT
    Rating_Category,
    COUNT(*) AS Restaurant_Count,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS Restaurant_Percentage
FROM Classified_Restaurants
GROUP BY Rating_Category
ORDER BY Restaurant_Count DESC;




-- =====================================================
-- STEP 35.1: RESTAURANT PRICE SEGMENTATION
-- =====================================================


WITH Restaurant_Pricing AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        AVG(f.price) AS Average_Price,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Average_Price,
    Total_Revenue,
    CASE
        WHEN Average_Price < 200 THEN 'Budget'
        WHEN Average_Price < 400 THEN 'Standard'
        WHEN Average_Price < 700 THEN 'Premium'
        ELSE 'Luxury'
    END AS Price_Category
FROM Restaurant_Pricing
ORDER BY Average_Price DESC;



-- =====================================================
-- STEP 35.2: PRICE CATEGORY DISTRIBUTION
-- =====================================================

WITH Restaurant_Pricing AS
(
    SELECT
        r.restaurant_id,
        AVG(f.price) AS Average_Price,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Classified_Restaurants AS
(
    SELECT
        CASE
            WHEN Average_Price < 200 THEN 'Budget'
            WHEN Average_Price < 400 THEN 'Standard'
            WHEN Average_Price < 700 THEN 'Premium'
            ELSE 'Luxury'
        END AS Price_Category,
        Total_Revenue
    FROM Restaurant_Pricing
)
SELECT
    Price_Category,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Revenue) AS Total_Revenue,
    AVG(Total_Revenue) AS Average_Restaurant_Revenue
FROM Classified_Restaurants
GROUP BY Price_Category
ORDER BY Total_Revenue DESC;





-- =====================================================
-- STEP 36.1: TOP 3 RESTAURANTS IN EACH CITY
-- =====================================================

WITH Restaurant_City_Revenue AS
(
    SELECT
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_location l
        ON f.location_id = l.location_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name
),
City_Ranking AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY city, state
            ORDER BY Total_Revenue DESC, restaurant_id
        ) AS City_Rank
    FROM Restaurant_City_Revenue
)
SELECT
    city,
    state,
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    City_Rank
FROM City_Ranking
WHERE City_Rank <= 3
ORDER BY city, City_Rank;




-- =====================================================
-- STEP 36.2: RESTAURANT COMPETITION BY CITY
-- =====================================================

SELECT
    l.city,
    l.state,
    COUNT(DISTINCT r.restaurant_id) AS Total_Restaurants,
    COUNT(*) AS Total_Orders,
    SUM(f.price) AS Total_Revenue
FROM dbo.fact_orders f
INNER JOIN dbo.dim_location l
    ON f.location_id = l.location_id
INNER JOIN dbo.dim_restaurant r
    ON f.restaurant_id = r.restaurant_id
GROUP BY
    l.city,
    l.state
ORDER BY Total_Restaurants DESC;




-- =====================================================
-- STEP 37.1: CITY-WISE RESTAURANT REVENUE CONTRIBUTION
-- =====================================================

WITH Restaurant_City_Revenue AS
(
    SELECT
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_location l
        ON f.location_id = l.location_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    city,
    state,
    restaurant_id,
    restaurant_name,
    Total_Revenue,
    SUM(Total_Revenue) OVER (
        PARTITION BY city, state
    ) AS City_Total_Revenue,
    CAST(
        Total_Revenue * 100.0 /
        NULLIF(
            SUM(Total_Revenue) OVER (
                PARTITION BY city, state
            ), 0
        )
        AS DECIMAL(10,2)
    ) AS City_Revenue_Contribution_Percentage
FROM Restaurant_City_Revenue
ORDER BY city, Total_Revenue DESC;



-- =====================================================
-- STEP 37.2: CITY-WISE CUMULATIVE REVENUE CONTRIBUTION
-- =====================================================

WITH Restaurant_City_Revenue AS
(
    SELECT
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_location l
        ON f.location_id = l.location_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name
),
City_Cumulative_Revenue AS
(
    SELECT
        *,
        SUM(Total_Revenue) OVER (
            PARTITION BY city, state
            ORDER BY Total_Revenue DESC, restaurant_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_Revenue,
        SUM(Total_Revenue) OVER (
            PARTITION BY city, state
        ) AS City_Total_Revenue
    FROM Restaurant_City_Revenue
)
SELECT
    city,
    state,
    restaurant_id,
    restaurant_name,
    Total_Revenue,
    Cumulative_Revenue,
    CAST(
        Cumulative_Revenue * 100.0 /
        NULLIF(City_Total_Revenue, 0)
        AS DECIMAL(10,2)
    ) AS Cumulative_Revenue_Percentage
FROM City_Cumulative_Revenue
ORDER BY city, Total_Revenue DESC;





-- =====================================================
-- STEP 38.1: RESTAURANTS REQUIRED TO REACH 80% REVENUE
-- =====================================================

WITH Restaurant_City_Revenue AS
(
    SELECT
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_location l
        ON f.location_id = l.location_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        l.city,
        l.state,
        r.restaurant_id,
        r.restaurant_name
),
Cumulative_Revenue AS
(
    SELECT
        *,
        SUM(Total_Revenue) OVER (
            PARTITION BY city, state
            ORDER BY Total_Revenue DESC, restaurant_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Running_Revenue,
        SUM(Total_Revenue) OVER (
            PARTITION BY city, state
        ) AS City_Total_Revenue,
        ROW_NUMBER() OVER (
            PARTITION BY city, state
            ORDER BY Total_Revenue DESC, restaurant_id
        ) AS Revenue_Rank
    FROM Restaurant_City_Revenue
),
City_80_Percent AS
(
    SELECT
        city,
        state,
        COUNT(*) AS Total_Restaurants,
        MIN(
            CASE
                WHEN Running_Revenue >= City_Total_Revenue * 0.80
                THEN Revenue_Rank
            END
        ) AS Restaurants_Required_For_80_Percent
    FROM Cumulative_Revenue
    GROUP BY city, state
)
SELECT
    city,
    state,
    Total_Restaurants,
    Restaurants_Required_For_80_Percent,
    CAST(
        Restaurants_Required_For_80_Percent * 100.0 /
        Total_Restaurants
        AS DECIMAL(10,2)
    ) AS Percentage_Of_Restaurants_Required
FROM City_80_Percent
ORDER BY Restaurants_Required_For_80_Percent DESC;



-- =====================================================
-- STEP 38.2: OVERALL CITY REVENUE CONCENTRATION
-- =====================================================

WITH Restaurant_City_Revenue AS
(
    SELECT
        l.city,
        l.state,
        r.restaurant_id,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_location l
        ON f.location_id = l.location_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        l.city,
        l.state,
        r.restaurant_id
),
Ranked_Revenue AS
(
    SELECT
        *,
        SUM(Total_Revenue) OVER (
            PARTITION BY city, state
            ORDER BY Total_Revenue DESC, restaurant_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Running_Revenue,
        SUM(Total_Revenue) OVER (
            PARTITION BY city, state
        ) AS City_Total_Revenue,
        ROW_NUMBER() OVER (
            PARTITION BY city, state
            ORDER BY Total_Revenue DESC, restaurant_id
        ) AS Revenue_Rank
    FROM Restaurant_City_Revenue
),
City_Summary AS
(
    SELECT
        city,
        state,
        MIN(
            CASE
                WHEN Running_Revenue >= City_Total_Revenue * 0.80
                THEN Revenue_Rank
            END
        ) AS Restaurants_Required_For_80_Percent,
        COUNT(*) AS Total_Restaurants
    FROM Ranked_Revenue
    GROUP BY city, state
)
SELECT
    COUNT(*) AS Total_Cities,
    SUM(Total_Restaurants) AS Total_Restaurants,
    AVG(
        CAST(Restaurants_Required_For_80_Percent AS DECIMAL(10,2))
    ) AS Average_Restaurants_Required_For_80_Percent,
    MIN(Restaurants_Required_For_80_Percent)
        AS Minimum_Restaurants_Required,
    MAX(Restaurants_Required_For_80_Percent)
        AS Maximum_Restaurants_Required
FROM City_Summary;




-- =====================================================
-- STEP 39.1: RATING CATEGORY VS REVENUE ANALYSIS
-- =====================================================

WITH Restaurant_Performance AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
),
Classified_Restaurants AS
(
    SELECT
        *,
        CASE
            WHEN Average_Rating >= 4.5 THEN 'Excellent'
            WHEN Average_Rating >= 4.0 THEN 'Good'
            ELSE 'Needs Improvement'
        END AS Rating_Category
    FROM Restaurant_Performance
)
SELECT
    Rating_Category,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Orders) AS Total_Orders,
    SUM(Total_Revenue) AS Total_Revenue,
    AVG(Total_Revenue) AS Average_Restaurant_Revenue,
    AVG(Average_Rating) AS Average_Rating
FROM Classified_Restaurants
GROUP BY Rating_Category
ORDER BY Total_Revenue DESC;



-- =====================================================
-- STEP 39.2: HIGH-REVENUE LOW-RATING RESTAURANTS
-- =====================================================

WITH Restaurant_Performance AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    Average_Rating
FROM Restaurant_Performance
WHERE Total_Revenue >= 100000
  AND Average_Rating < 4.0
ORDER BY Total_Revenue DESC;



-- =====================================================
-- STEP 39.3: LOW-REVENUE HIGH-RATING RESTAURANTS
-- =====================================================

WITH Restaurant_Performance AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    Average_Rating
FROM Restaurant_Performance
WHERE Total_Revenue < 100000
  AND Average_Rating >= 4.5
ORDER BY Average_Rating DESC, Total_Revenue DESC;





-- =====================================================
-- STEP 40.1: RESTAURANT REVENUE QUARTILE ANALYSIS
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
),
Revenue_Quartiles AS
(
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY Total_Revenue DESC
        ) AS Revenue_Quartile
    FROM Restaurant_Revenue
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    Average_Rating,
    Revenue_Quartile,
    CASE
        WHEN Revenue_Quartile = 1 THEN 'Top 25%'
        WHEN Revenue_Quartile = 2 THEN 'Upper Middle 25%'
        WHEN Revenue_Quartile = 3 THEN 'Lower Middle 25%'
        ELSE 'Bottom 25%'
    END AS Revenue_Segment
FROM Revenue_Quartiles
ORDER BY Revenue_Quartile, Total_Revenue DESC;




-- =====================================================
-- STEP 40.2: REVENUE QUARTILE SUMMARY
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Revenue_Quartiles AS
(
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY Total_Revenue DESC
        ) AS Revenue_Quartile
    FROM Restaurant_Revenue
)
SELECT
    Revenue_Quartile,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Orders) AS Total_Orders,
    SUM(Total_Revenue) AS Total_Revenue,
    AVG(Total_Revenue) AS Average_Restaurant_Revenue,
    AVG(Average_Rating) AS Average_Rating
FROM Revenue_Quartiles
GROUP BY Revenue_Quartile
ORDER BY Revenue_Quartile;




-- =====================================================
-- STEP 40.3: REVENUE QUARTILE VS RATING CATEGORY
-- =====================================================

WITH Restaurant_Performance AS
(
    SELECT
        r.restaurant_id,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue,
        AVG(f.rating) AS Average_Rating
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Classified_Restaurants AS
(
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY Total_Revenue DESC
        ) AS Revenue_Quartile,
        CASE
            WHEN Average_Rating >= 4.5 THEN 'Excellent'
            WHEN Average_Rating >= 4.0 THEN 'Good'
            ELSE 'Needs Improvement'
        END AS Rating_Category
    FROM Restaurant_Performance
)
SELECT
    Revenue_Quartile,
    Rating_Category,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Revenue) AS Total_Revenue,
    AVG(Average_Rating) AS Average_Rating
FROM Classified_Restaurants
GROUP BY
    Revenue_Quartile,
    Rating_Category
ORDER BY
    Revenue_Quartile,
    Rating_Category;




-- =====================================================
-- STEP 41.1: RESTAURANT MONTHLY REVENUE GROWTH
-- =====================================================


WITH Monthly_Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Revenue_Growth AS
(
    SELECT
        *,
        LAG(Monthly_Revenue) OVER
        (
            PARTITION BY restaurant_id
            ORDER BY Order_Year, Order_Month
        ) AS Previous_Month_Revenue
    FROM Monthly_Restaurant_Revenue
)
SELECT
    restaurant_id,
    restaurant_name,
    Order_Year,
    Order_Month,
    Total_Orders,
    Monthly_Revenue,
    Previous_Month_Revenue,
    Monthly_Revenue - Previous_Month_Revenue AS Revenue_Change,
    CAST(
        (Monthly_Revenue - Previous_Month_Revenue)
        * 100.0 /
        NULLIF(Previous_Month_Revenue, 0)
        AS DECIMAL(10,2)
    ) AS MoM_Growth_Percentage
FROM Revenue_Growth
ORDER BY
    restaurant_id,
    Order_Year,
    Order_Month;





-- =====================================================
-- STEP 41.2: MONTHLY TOP 3 RESTAURANT RANKING
-- =====================================================

WITH Monthly_Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Monthly_Ranking AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY Order_Year, Order_Month
            ORDER BY Monthly_Revenue DESC, restaurant_id
        ) AS Monthly_Rank
    FROM Monthly_Restaurant_Revenue
)
SELECT
    Order_Year,
    Order_Month,
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Monthly_Revenue,
    Monthly_Rank
FROM Monthly_Ranking
WHERE Monthly_Rank <= 3
ORDER BY Order_Year, Order_Month, Monthly_Rank;



-- =====================================================
-- STEP 42.1: RESTAURANT REVENUE VOLATILITY ANALYSIS
-- =====================================================


WITH Monthly_Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date),
        MONTH(d.order_date)
)
SELECT
    restaurant_id,
    restaurant_name,
    COUNT(*) AS Active_Months,
    AVG(Monthly_Revenue) AS Average_Monthly_Revenue,
    STDEV(Monthly_Revenue) AS Revenue_Standard_Deviation,
    MIN(Monthly_Revenue) AS Minimum_Monthly_Revenue,
    MAX(Monthly_Revenue) AS Maximum_Monthly_Revenue
FROM Monthly_Restaurant_Revenue
GROUP BY
    restaurant_id,
    restaurant_name
ORDER BY Revenue_Standard_Deviation DESC;



-- =====================================================
-- STEP 42.2: RESTAURANT REVENUE STABILITY CLASSIFICATION
-- =====================================================

WITH Monthly_Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Revenue_Stability AS
(
    SELECT
        restaurant_id,
        restaurant_name,
        COUNT(*) AS Active_Months,
        AVG(Monthly_Revenue) AS Average_Monthly_Revenue,
        STDEV(Monthly_Revenue) AS Revenue_Standard_Deviation
    FROM Monthly_Restaurant_Revenue
    GROUP BY
        restaurant_id,
        restaurant_name
)
SELECT
    restaurant_id,
    restaurant_name,
    Active_Months,
    Average_Monthly_Revenue,
    Revenue_Standard_Deviation,
    CASE
        WHEN Revenue_Standard_Deviation IS NULL
            THEN 'Insufficient Data'
        WHEN Revenue_Standard_Deviation /
             NULLIF(Average_Monthly_Revenue, 0) < 0.20
            THEN 'Highly Stable'
        WHEN Revenue_Standard_Deviation /
             NULLIF(Average_Monthly_Revenue, 0) < 0.50
            THEN 'Moderately Stable'
        ELSE 'Highly Volatile'
    END AS Revenue_Stability
FROM Revenue_Stability
ORDER BY Revenue_Standard_Deviation DESC;



-- =====================================================
-- STEP 42.3: OVERALL RESTAURANT REVENUE STABILITY PROFILE
-- =====================================================

WITH Monthly_Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Revenue_Stability AS
(
    SELECT
        restaurant_id,
        AVG(Monthly_Revenue) AS Average_Monthly_Revenue,
        STDEV(Monthly_Revenue) AS Revenue_Standard_Deviation
    FROM Monthly_Restaurant_Revenue
    GROUP BY restaurant_id
),
Classified_Restaurants AS
(
    SELECT
        CASE
            WHEN Revenue_Standard_Deviation IS NULL
                THEN 'Insufficient Data'
            WHEN Revenue_Standard_Deviation /
                 NULLIF(Average_Monthly_Revenue, 0) < 0.20
                THEN 'Highly Stable'
            WHEN Revenue_Standard_Deviation /
                 NULLIF(Average_Monthly_Revenue, 0) < 0.50
                THEN 'Moderately Stable'
            ELSE 'Highly Volatile'
        END AS Revenue_Stability
    FROM Revenue_Stability
)
SELECT
    Revenue_Stability,
    COUNT(*) AS Restaurant_Count,
    CAST(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
        AS DECIMAL(10,2)
    ) AS Restaurant_Percentage
FROM Classified_Restaurants
GROUP BY Revenue_Stability
ORDER BY Restaurant_Count DESC;



-- =====================================================
-- STEP 43.1: HIGH-REVENUE STABLE RESTAURANTS
-- =====================================================

WITH Monthly_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name,
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Stability AS
(
    SELECT
        restaurant_id,
        restaurant_name,
        COUNT(*) AS Active_Months,
        SUM(Monthly_Revenue) AS Total_Revenue,
        AVG(Monthly_Revenue) AS Average_Monthly_Revenue,
        STDEV(Monthly_Revenue) AS Revenue_Standard_Deviation
    FROM Monthly_Revenue
    GROUP BY
        restaurant_id,
        restaurant_name
),
Classified AS
(
    SELECT
        *,
        Revenue_Standard_Deviation /
            NULLIF(Average_Monthly_Revenue, 0) AS Revenue_CV,
        CASE
            WHEN Revenue_Standard_Deviation IS NULL
                THEN 'Insufficient Data'
            WHEN Revenue_Standard_Deviation /
                 NULLIF(Average_Monthly_Revenue, 0) < 0.20
                THEN 'Highly Stable'
            WHEN Revenue_Standard_Deviation /
                 NULLIF(Average_Monthly_Revenue, 0) < 0.50
                THEN 'Moderately Stable'
            ELSE 'Highly Volatile'
        END AS Revenue_Stability
    FROM Stability
),
Revenue_Ranking AS
(
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY Total_Revenue DESC
        ) AS Revenue_Quartile
    FROM Classified
)
SELECT
    restaurant_id,
    restaurant_name,
    Active_Months,
    Total_Revenue,
    Average_Monthly_Revenue,
    Revenue_Standard_Deviation,
    CAST(Revenue_CV * 100 AS DECIMAL(10,2))
        AS Revenue_CV_Percentage,
    Revenue_Stability
FROM Revenue_Ranking
WHERE Revenue_Quartile = 1
  AND Revenue_Stability IN
      ('Highly Stable', 'Moderately Stable')
ORDER BY Total_Revenue DESC;



-- =====================================================
-- STEP 43.2: HIGH-REVENUE STABLE RESTAURANT SUMMARY
-- =====================================================

WITH Monthly_Revenue AS
(
    SELECT
        r.restaurant_id,
        YEAR(d.order_date) AS Order_Year,
        MONTH(d.order_date) AS Order_Month,
        SUM(f.price) AS Monthly_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_date d
        ON f.date_id = d.date_id
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        YEAR(d.order_date),
        MONTH(d.order_date)
),
Stability AS
(
    SELECT
        restaurant_id,
        SUM(Monthly_Revenue) AS Total_Revenue,
        AVG(Monthly_Revenue) AS Average_Monthly_Revenue,
        STDEV(Monthly_Revenue) AS Revenue_Standard_Deviation
    FROM Monthly_Revenue
    GROUP BY restaurant_id
),
Classified AS
(
    SELECT
        *,
        CASE
            WHEN Revenue_Standard_Deviation IS NULL
                THEN 'Insufficient Data'
            WHEN Revenue_Standard_Deviation /
                 NULLIF(Average_Monthly_Revenue, 0) < 0.20
                THEN 'Highly Stable'
            WHEN Revenue_Standard_Deviation /
                 NULLIF(Average_Monthly_Revenue, 0) < 0.50
                THEN 'Moderately Stable'
            ELSE 'Highly Volatile'
        END AS Revenue_Stability
    FROM Stability
),
Revenue_Ranking AS
(
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY Total_Revenue DESC
        ) AS Revenue_Quartile
    FROM Classified
)
SELECT
    Revenue_Stability,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Revenue) AS Total_Revenue,
    AVG(Total_Revenue) AS Average_Restaurant_Revenue
FROM Revenue_Ranking
WHERE Revenue_Quartile = 1
  AND Revenue_Stability IN
      ('Highly Stable', 'Moderately Stable')
GROUP BY Revenue_Stability
ORDER BY Total_Revenue DESC;




-- =====================================================
-- STEP 44.1: OVERALL RESTAURANT REVENUE CONTRIBUTION
-- =====================================================


WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        COUNT(*) AS Total_Orders,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
),
Revenue_Contribution AS
(
    SELECT
        *,
        SUM(Total_Revenue) OVER () AS Overall_Revenue,
        SUM(Total_Revenue) OVER
        (
            ORDER BY Total_Revenue DESC, restaurant_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_Revenue,
        ROW_NUMBER() OVER
        (
            ORDER BY Total_Revenue DESC, restaurant_id
        ) AS Revenue_Rank
    FROM Restaurant_Revenue
)
SELECT
    restaurant_id,
    restaurant_name,
    Total_Orders,
    Total_Revenue,
    CAST(
        Total_Revenue * 100.0 / NULLIF(Overall_Revenue, 0)
        AS DECIMAL(10,2)
    ) AS Revenue_Contribution_Percentage,
    Cumulative_Revenue,
    CAST(
        Cumulative_Revenue * 100.0 / NULLIF(Overall_Revenue, 0)
        AS DECIMAL(10,2)
    ) AS Cumulative_Revenue_Percentage,
    Revenue_Rank
FROM Revenue_Contribution
ORDER BY Revenue_Rank;



-- =====================================================
-- STEP 44.2: OVERALL REVENUE 80% PARETO ANALYSIS
-- Purpose: Identify how many restaurants contribute
--          at least 80% of total revenue.
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Cumulative_Revenue AS
(
    SELECT
        restaurant_id,
        Total_Revenue,
        SUM(Total_Revenue) OVER
        (
            ORDER BY Total_Revenue DESC, restaurant_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_Revenue,
        SUM(Total_Revenue) OVER () AS Overall_Revenue,
        ROW_NUMBER() OVER
        (
            ORDER BY Total_Revenue DESC, restaurant_id
        ) AS Revenue_Rank
    FROM Restaurant_Revenue
)
SELECT
    COUNT(*) AS Total_Restaurants,
    MIN(
        CASE
            WHEN Cumulative_Revenue >= Overall_Revenue * 0.80
            THEN Revenue_Rank
        END
    ) AS Restaurants_Required_For_80_Percent,
    CAST(
        MIN(
            CASE
                WHEN Cumulative_Revenue >= Overall_Revenue * 0.80
                THEN Revenue_Rank
            END
        ) * 100.0 / COUNT(*)
        AS DECIMAL(10,2)
    ) AS Percentage_Of_Restaurants_Required,
    MAX(Overall_Revenue) AS Overall_Revenue
FROM Cumulative_Revenue;



-- =====================================================
-- STEP 44.3: OVERALL PARETO REVENUE SUMMARY
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_id
),
Ranked_Revenue AS
(
    SELECT
        *,
        SUM(Total_Revenue) OVER
        (
            ORDER BY Total_Revenue DESC, restaurant_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_Revenue,
        SUM(Total_Revenue) OVER () AS Overall_Revenue,
        ROW_NUMBER() OVER
        (
            ORDER BY Total_Revenue DESC, restaurant_id
        ) AS Revenue_Rank
    FROM Restaurant_Revenue
)
SELECT
    CASE
        WHEN Revenue_Rank <= 10 THEN 'Top 10 Restaurants'
        WHEN Revenue_Rank <= 25 THEN 'Top 25 Restaurants'
        WHEN Revenue_Rank <= 50 THEN 'Top 50 Restaurants'
        WHEN Revenue_Rank <= 100 THEN 'Top 100 Restaurants'
        ELSE 'Remaining Restaurants'
    END AS Restaurant_Group,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Revenue) AS Total_Revenue,
    CAST(
        SUM(Total_Revenue) * 100.0 /
        MAX(Overall_Revenue)
        AS DECIMAL(10,2)
    ) AS Revenue_Contribution_Percentage
FROM Ranked_Revenue
GROUP BY
    CASE
        WHEN Revenue_Rank <= 10 THEN 'Top 10 Restaurants'
        WHEN Revenue_Rank <= 25 THEN 'Top 25 Restaurants'
        WHEN Revenue_Rank <= 50 THEN 'Top 50 Restaurants'
        WHEN Revenue_Rank <= 100 THEN 'Top 100 Restaurants'
        ELSE 'Remaining Restaurants'
    END,
    CASE
        WHEN Revenue_Rank <= 10 THEN 1
        WHEN Revenue_Rank <= 25 THEN 2
        WHEN Revenue_Rank <= 50 THEN 3
        WHEN Revenue_Rank <= 100 THEN 4
        ELSE 5
    END
ORDER BY
    CASE
        WHEN Revenue_Rank <= 10 THEN 1
        WHEN Revenue_Rank <= 25 THEN 2
        WHEN Revenue_Rank <= 50 THEN 3
        WHEN Revenue_Rank <= 100 THEN 4
        ELSE 5
    END;



-- =====================================================
-- VALIDATION 1: PRICE SEGMENTATION REVENUE RECONCILIATION
-- =====================================================

WITH Restaurant_Revenue AS
(
    SELECT
        r.restaurant_id,
        r.restaurant_name,
        AVG(f.price) AS Average_Price,
        SUM(f.price) AS Total_Revenue
    FROM dbo.fact_orders f
    INNER JOIN dbo.dim_restaurant r
        ON f.restaurant_id = r.restaurant_id
    GROUP BY
        r.restaurant_id,
        r.restaurant_name
),
Price_Segmentation AS
(
    SELECT
        *,
        CASE
            WHEN Average_Price < 200 THEN 'Budget'
            WHEN Average_Price < 400 THEN 'Standard'
            WHEN Average_Price < 700 THEN 'Premium'
            ELSE 'Luxury'
        END AS Price_Category
    FROM Restaurant_Revenue
)
SELECT
    Price_Category,
    COUNT(*) AS Restaurant_Count,
    SUM(Total_Revenue) AS Total_Revenue
FROM Price_Segmentation
GROUP BY Price_Category

UNION ALL

SELECT
    'GRAND TOTAL',
    COUNT(*),
    SUM(Total_Revenue)
FROM Price_Segmentation;



-- =====================================================
-- VALIDATION 2.1: LOCATION NAME CONSISTENCY
-- Purpose: Identify repeated location labels and check
--          whether they map to different cities/states.
-- =====================================================

WITH Normalized_Locations AS
(
    SELECT
        location_id,
        location,
        city,
        state,
        UPPER(LTRIM(RTRIM(location))) AS Normalized_Location
    FROM dbo.dim_location
)
SELECT
    Normalized_Location,
    COUNT(*) AS Location_Record_Count,
    COUNT(DISTINCT city) AS Unique_Cities,
    COUNT(DISTINCT state) AS Unique_States,
    COUNT(DISTINCT location_id) AS Unique_Location_IDs
FROM Normalized_Locations
GROUP BY Normalized_Location
HAVING COUNT(*) > 1
ORDER BY Location_Record_Count DESC,
         Normalized_Location;



-- =====================================================
-- VALIDATION 2.2: INSPECT REPEATED LOCATION RECORDS
-- Purpose: Review the original location labels,
--          city and state for repeated normalized names.
-- =====================================================

WITH Normalized_Locations AS
(
    SELECT
        location_id,
        location,
        city,
        state,
        UPPER(LTRIM(RTRIM(location))) AS Normalized_Location
    FROM dbo.dim_location
),
Repeated_Locations AS
(
    SELECT Normalized_Location
    FROM Normalized_Locations
    GROUP BY Normalized_Location
    HAVING COUNT(*) > 1
)
SELECT
    n.location_id,
    n.location,
    n.Normalized_Location,
    n.city,
    n.state
FROM Normalized_Locations n
INNER JOIN Repeated_Locations r
    ON n.Normalized_Location = r.Normalized_Location
ORDER BY
    n.Normalized_Location,
    n.city,
    n.state,
    n.location_id;



-- =====================================================
-- VALIDATION 2.3: POSSIBLE DUPLICATE LOCATION RECORDS
-- Purpose: Identify repeated normalized location names
--          within the same city and state.
-- =====================================================

WITH Normalized_Locations AS
(
    SELECT
        location_id,
        location,
        city,
        state,
        UPPER(LTRIM(RTRIM(location))) AS Normalized_Location,
        UPPER(LTRIM(RTRIM(city))) AS Normalized_City,
        UPPER(LTRIM(RTRIM(state))) AS Normalized_State
    FROM dbo.dim_location
)
SELECT
    Normalized_Location,
    Normalized_City,
    Normalized_State,
    COUNT(*) AS Location_Record_Count,
    COUNT(DISTINCT location_id) AS Unique_Location_IDs
FROM Normalized_Locations
GROUP BY
    Normalized_Location,
    Normalized_City,
    Normalized_State
HAVING COUNT(*) > 1
ORDER BY Location_Record_Count DESC,
         Normalized_Location;



    -- =====================================================
-- VALIDATION 2.4: FACT TABLE USAGE OF DUPLICATE LOCATIONS
-- Purpose: Check how many orders reference each
--          potentially duplicated location ID.
-- =====================================================


WITH Normalized_Locations AS
(
    SELECT
        location_id,
        location,
        city,
        state,
        UPPER(LTRIM(RTRIM(location))) AS Normalized_Location,
        UPPER(LTRIM(RTRIM(city))) AS Normalized_City,
        UPPER(LTRIM(RTRIM(state))) AS Normalized_State
    FROM dbo.dim_location
),
Duplicate_Groups AS
(
    SELECT
        Normalized_Location,
        Normalized_City,
        Normalized_State
    FROM Normalized_Locations
    GROUP BY
        Normalized_Location,
        Normalized_City,
        Normalized_State
    HAVING COUNT(*) > 1
)
SELECT
    l.location_id,
    l.location,
    l.city,
    l.state,
    COUNT(f.order_id) AS Referencing_Orders
FROM Normalized_Locations l
INNER JOIN Duplicate_Groups d
    ON l.Normalized_Location = d.Normalized_Location
   AND l.Normalized_City = d.Normalized_City
   AND l.Normalized_State = d.Normalized_State
LEFT JOIN dbo.fact_orders f
    ON l.location_id = f.location_id
GROUP BY
    l.location_id,
    l.location,
    l.city,
    l.state
ORDER BY
    l.Normalized_Location,
    l.location_id;





-- =====================================================
-- VALIDATION 2.4: FACT TABLE USAGE OF DUPLICATE LOCATIONS
-- Purpose: Check order references for potentially
--          duplicated location IDs.
-- =====================================================

WITH Normalized_Locations AS
(
    SELECT
        location_id,
        location,
        city,
        state,
        UPPER(LTRIM(RTRIM(location))) AS Normalized_Location,
        UPPER(LTRIM(RTRIM(city))) AS Normalized_City,
        UPPER(LTRIM(RTRIM(state))) AS Normalized_State
    FROM dbo.dim_location
),
Duplicate_Groups AS
(
    SELECT
        Normalized_Location,
        Normalized_City,
        Normalized_State
    FROM Normalized_Locations
    GROUP BY
        Normalized_Location,
        Normalized_City,
        Normalized_State
    HAVING COUNT(*) > 1
)
SELECT
    l.Normalized_Location,
    l.location_id,
    l.location,
    l.city,
    l.state,
    COUNT(f.order_id) AS Referencing_Orders
FROM Normalized_Locations l
INNER JOIN Duplicate_Groups d
    ON l.Normalized_Location = d.Normalized_Location
   AND l.Normalized_City = d.Normalized_City
   AND l.Normalized_State = d.Normalized_State
LEFT JOIN dbo.fact_orders f
    ON l.location_id = f.location_id
GROUP BY
    l.Normalized_Location,
    l.location_id,
    l.location,
    l.city,
    l.state
ORDER BY
    l.Normalized_Location,
    l.location_id;
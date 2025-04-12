-- Этап 1. Создание и заполнение БД
-- Шаг 2. Создание схемы raw_data и таблицы sales
CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY, -- автоинкремент для идентификатора
    auto VARCHAR(255), -- бренд, название машины и цвет
    gasoline_consumption INTEGER, -- потребление бензина
    price NUMERIC(10, 2), -- цена с учётом скидки
    date DATE, -- дата покупки
    person VARCHAR(255), -- ФИО покупателя
    phone VARCHAR(20), -- телефон покупателя
    discount NUMERIC(5, 2), -- размер скидки в процентах
    brand_origin VARCHAR(100) -- страна происхождения бренда
);

-- Шаг 3. Заполнение таблицы sales данными
\COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person, phone, discount, brand_origin)
FROM '/Users/daryl/cars.csv' DELIMITER ',' CSV HEADER;
--не сработало, поэтому использовала импорт файла csv в DBeaver

-- Пример данных
SELECT * FROM raw_data.sales LIMIT 5;
-- Шаг 4. Анализ сырых данных
-- Создание схемы car_shop и нормализованных таблиц

CREATE SCHEMA car_shop;

-- Таблица brands
CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL
);

-- Таблица colors
CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY,
    color_name VARCHAR(50) NOT NULL
);

-- Таблица cars
CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    brand_id INTEGER REFERENCES car_shop.brands(brand_id),
    model_name VARCHAR(100) NOT NULL,
    gasoline_consumption INTEGER,
    price NUMERIC(10, 2) NOT NULL
);

-- Таблица sales
CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY,
    car_id INTEGER REFERENCES car_shop.cars(car_id),
    sale_date DATE NOT NULL,
    person_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    discount NUMERIC(5, 2),
    brand_origin VARCHAR(100)
);
-- Таблица car_colors (для связи многие-ко-многим)
CREATE TABLE car_shop.car_colors (
    car_id INTEGER REFERENCES car_shop.cars(car_id),
    color_id INTEGER REFERENCES car_shop.colors(color_id),
    PRIMARY KEY (car_id, color_id)
);
-- Шаг 7. Заполнение нормализованных таблиц
INSERT INTO car_shop.brands (brand_name)
SELECT DISTINCT split_part(auto, ' ', 1) FROM raw_data.sales;

INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT split_part(auto, ' ', 3) FROM raw_data.sales;

INSERT INTO car_shop.cars (brand_id, model_name, gasoline_consumption, price)
SELECT 
    (SELECT brand_id FROM car_shop.brands WHERE brand_name = split_part(auto, ' ', 1)),
    split_part(auto, ' ', 2),
    gasoline_consumption,
    price
FROM raw_data.sales;

INSERT INTO car_shop.sales (car_id, sale_date, person_name, phone, discount, brand_origin)
SELECT 
    (SELECT car_id FROM car_shop.cars WHERE model_name = split_part(auto, ' ', 2) AND brand_id = (SELECT brand_id FROM car_shop.brands WHERE brand_name = split_part(auto, ' ', 1))),
    date,
    person,
    phone,
    discount,
    brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.car_colors (car_id, color_id)
SELECT 
    (SELECT car_id FROM car_shop.cars WHERE model_name = split_part(auto, ' ', 2) AND brand_id = (SELECT brand_id FROM car_shop.brands WHERE brand_name = split_part(auto, ' ', 1))),
    (SELECT color_id FROM car_shop.colors WHERE color_name = split_part(auto, ' ', 3))
FROM raw_data.sales;

-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT 
    ROUND((COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0 / COUNT(*)), 2) 
    AS nulls_percentage_gasoline_consumption
FROM car_shop.cars;


---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT 
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100)), 2) AS price_avg
FROM car_shop.sales s
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.brands b ON c.brand_id = b.brand_id
GROUP BY b.brand_name, year
ORDER BY b.brand_name, year;


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT 
    EXTRACT(MONTH FROM s.sale_date) AS month,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(c.price * (1 - s.discount / 100)), 2) AS price_avg
FROM sales s
JOIN cars c ON s.car_id = c.id
WHERE EXTRACT(YEAR FROM s.sale_date) = 2022
GROUP BY month, year
ORDER BY month;


---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.
SELECT 
    c.full_name AS person,
    STRING_AGG(CONCAT(b.brand_name, ' ', m.model_name), ', ') AS cars
FROM car_shop.sales s
JOIN car_shop.customers c ON s.person_name = c.full_name AND s.phone = c.phone
JOIN car_shop.cars m ON s.car_id = m.car_id
JOIN car_shop.brands b ON m.brand_id = b.brand_id
GROUP BY c.full_name
ORDER BY c.full_name;


---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.

SELECT 
    COUNT(*) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';



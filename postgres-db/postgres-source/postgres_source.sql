create table public.sales
(
id int,
creation_date date,
sales_value numeric(10,2)
);

insert into public.sales (id, creation_date, sales_value) values (0,'2022-07-20', 100);
insert into public.sales (id, creation_date, sales_value) values (1,'2022-07-20', 200);
insert into public.sales (id, creation_date, sales_value) values (2,'2022-07-20', 400);

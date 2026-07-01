/*
3.	Оптимизация SQL запроса
Формулировка задачи:
Вам необходимо оптимизировать SQL-запрос, который анализирует данные о клиентах банка, их счетах и транзакциях. 
В качестве решения предоставьте оптимизированный запрос и краткое описание внесенных изменений.
*/

--explain analyze -- 128 / 120
with client_stats as (
    select 
        a.client_id,
        count(a.account_id) as total_accounts,
        sum(a.balance) as total_balance
    from accounts a
    group by a.client_id
),
transaction_stats as (
    select 
        a.client_id,
        count(case when t.transaction_type = 'deposit' then 1 end) as total_deposits,
        count(case when t.transaction_type = 'withdrawal' then 1 end) as total_withdrawals
    from accounts a
    join transactions t on a.account_id = t.account_id
    group by a.client_id
)
select 
    c.client_id, 
    c.name, 
    c.age,
    coalesce(cs.total_accounts, 0) as total_accounts,
    coalesce(cs.total_balance, 0) as total_balance,
    coalesce(ts.total_deposits, 0) as total_deposits,
    coalesce(ts.total_withdrawals, 0) as total_withdrawals
from clients c
left join client_stats cs on c.client_id = cs.client_id
left join transaction_stats ts on c.client_id = ts.client_id
where c.registration_date >= '2020-01-01'
order by cs.total_balance desc;

-- Исходный запрос:

explain analyze -- 12311 / 325
select c.client_id, c.name, c.age,
(select count(*) from accounts a where a.client_id = c.client_id) as total_accounts,
(select sum(a.balance) from accounts a where a.client_id = c.client_id) as total_balance,
(select count(*) from transactions t join accounts a on t.account_id = a.account_id where a.client_id = c.client_id and t.transaction_type = 'deposit') as total_deposits,
(select count(*) from transactions t join accounts a on t.account_id = a.account_id where a.client_id = c.client_id and t.transaction_type = 'withdrawal') as total_withdrawals
from clients c where c.registration_date >= '2020-01-01' order by total_balance desc;

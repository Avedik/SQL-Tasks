/*
1.	Активность пользователей
Формулировка задачи:
Напишите SQL-запрос, который возвращает список пользователей с их ролями и количеством активностей за последний месяц. 
Учитывайте только те активности, которые были зарегистрированы в течение этого периода. 
Результаты должны быть отсортированы по количеству активностей в порядке убывания.
*/

with user_activities_last_month as (
    select user_id, count(id) as activity_count
    from user_activity
    -- ТРЕБУЕТСЯ УТОЧНЕНИЕ ФРАЗЫ "за последний месяц":
    -- where activity_date >= current_date - interval '1 month'
    where activity_date >= '2024-10-01' and activity_date < '2024-11-01'
    group by user_id
)
select 
    u.id,
    u.username,
    string_agg(ur.role, ', ') as roles,
    ua.activity_count
from users u
join user_activities_last_month ua on u.id = ua.user_id
left join user_roles ur on u.id = ur.user_id
group by u.id, u.username, ua.activity_count
order by ua.activity_count desc;

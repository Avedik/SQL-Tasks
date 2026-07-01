/*
1.	Активность пользователей
Формулировка задачи:
Напишите SQL-запрос, который возвращает список пользователей с их ролями и количеством активностей за последний месяц. 
Учитывайте только те активности, которые были зарегистрированы в течение этого периода. 
Результаты должны быть отсортированы по количеству активностей в порядке убывания.
*/

with activity_stats as (
    select 
        user_id, 
        count(id) as act_count
    from user_activity
    -- where activity_date >= current_date - interval '1 month'
    where activity_date >= '2024-10-01' and activity_date <= '2024-10-31'
    group by user_id
),
role_stats as (
    select 
        user_id, 
        string_agg(role, ', ') as roles
    from user_roles
    group by user_id
)
select 
    u.id,
    u.username,
    coalesce(rs.roles, 'нет роли') as roles,
    coalesce(ast.act_count, 0) as activity_count
from users u
left join role_stats rs on u.id = rs.user_id
left join activity_stats ast on u.id = ast.user_id
order by activity_count desc;

-- ТРЕБУЕТСЯ УТОЧНЕНИЕ ФРАЗЫ "за последний месяц" 
/*select
    u.id,
    u.username,
    string_agg(distinct ur.role, ', ' order by ur.role) as roles,
    count(distinct ua.id)                                as activity_count
from users u
left join user_roles ur
       on ur.user_id = u.id
left join user_activity ua
       on ua.user_id = u.id
      and ua.activity_date >= date_trunc('month', current_date - interval '1 month')
      and ua.activity_date <  date_trunc('month', current_date)
group by u.id, u.username
order by activity_count desc, u.username;*/
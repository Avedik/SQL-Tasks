/*
2.	Фильтрация транзакций
Формулировка задачи:

Вам поступила задача, которая заключается в разработке SQL-запроса для анализа данных о кредитных траншах (выплатах по кредитам от банка) 
и транзакциях (расходных операциях) клиентов. Необходимо найти по имеющимся таблицам кредитных траншей (tranches) 
и расходных операций (transactions) операции клиентов с контрагентами, соответствующие одному из двух условий:

1) суммы которых "копейка в копейку" равны сумме зачисления при проверке расходных операций в периоде T+10 дней, где T - дата и время транша

2) если не срабатывает пункт 1, для сопоставления транша и расходной операции, находимо собрать для транша все расходные операции, 
сумма которых превышает сумму транша (учитывая превысившую транзакцию).

Анализ требуется провести за 2024 год.
*/

with matched_tx as (
    -- 1. Фильтруем транши и собираем все потенциальные транзакции в окне t+10 дней
    select
        tr.doc_id as tranche_doc_id,
        tr.operation_sum as tranche_sum,
        tr.operation_datetime as tranche_dt,
        tx.doc_id as tx_doc_id,
        tx.operation_sum as tx_sum,
        tx.operation_datetime as tx_dt,
        tx.ctrg_inn,
        tx.ctrg_account
    from tranches tr
    join transactions tx
      on tx.inn::text = tr.inn
     and tx.account = tr.account
     and tx.operation_datetime between tr.operation_datetime 
                                   and tr.operation_datetime + interval '10 days'
    where tr.operation_datetime >= date '2024-01-01'
      and tr.operation_datetime <  date '2025-01-01'
),
rule1_matches as (
    -- 2. правило 1: ищем точное совпадение
    select distinct on (tranche_doc_id)
        tranche_doc_id,
        tranche_sum,
        'rule 1' as match_rule,
        tx_doc_id,
        tx_dt,
        tx_sum,
        ctrg_inn,
        ctrg_account
    from matched_tx
    where tx_sum = tranche_sum
    order by tranche_doc_id, tx_dt, tx_doc_id
),
rule2_filtered as (
    -- 3. правило 2: считаем сумму с накоплением только для тех, кто не попал в правило 1
    select
        tranche_doc_id,
        tranche_sum,
        'rule 2' as match_rule,
        tx_doc_id,
        tx_dt,
        tx_sum,
        ctrg_inn,
        ctrg_account
    from (
        select
            m.*,
            coalesce(sum(m.tx_sum) over (
                partition by m.tranche_doc_id
                order by m.tx_dt, m.tx_doc_id
                rows between unbounded preceding and 1 preceding
            ), 0) as prev_running_sum
        from matched_tx m
        where not exists (
            select 1 from rule1_matches r1 where r1.tranche_doc_id = m.tranche_doc_id
        )
    ) s
    where prev_running_sum < tranche_sum
)
-- 4. итоговое объединение
select * from rule1_matches
union all
select * from rule2_filtered
order by tranche_doc_id, tx_dt, tx_doc_id;

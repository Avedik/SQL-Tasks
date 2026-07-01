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

with valid_tranches as (
    select *
    from tranches
    where operation_datetime >= date '2024-01-01'
      and operation_datetime <  date '2025-01-01'
),
matched_tx as (
    -- первичное соединение в рамках окна t+10 дней
    select
        tr.doc_id as tranche_doc_id,
        tr.operation_sum as tranche_sum,
        tr.operation_datetime as tranche_dt,
        tx.doc_id as tx_doc_id,
        tx.operation_sum as tx_sum,
        tx.operation_datetime as tx_dt,
        tx.ctrg_inn,
        tx.ctrg_account
    from valid_tranches tr
    join transactions tx
      on tx.inn::text = tr.inn
     and tx.account = tr.account
     and tx.operation_datetime between tr.operation_datetime
                                   and tr.operation_datetime + interval '10 days'
),
rule1_matches as (
    -- правило 1: ищем точное совпадение. 
    -- если их несколько, детерминированно берем первую по времени.
    select distinct on (tranche_doc_id)
           tranche_doc_id,
           tx_doc_id
    from matched_tx
    where tx_sum = tranche_sum
    order by tranche_doc_id, tx_dt, tx_doc_id
),
rule2_pool as (
    -- отсеиваем транши, которые уже закрыты по правилу 1
    select m.*
    from matched_tx m
    left join rule1_matches r1
           on m.tranche_doc_id = r1.tranche_doc_id
    where r1.tranche_doc_id is null
),
rule2_filtered as (
    -- правило 2: считаем сумму предыдущих транзакций и останавливаемся при превышении
    select *
    from (
        select
            rt.*,
            coalesce(
                sum(tx_sum) over (
                    partition by tranche_doc_id
                    order by tx_dt, tx_doc_id
                    rows between unbounded preceding and 1 preceding
                ),
                0
            ) as prev_running_sum
        from rule2_pool rt
    ) s
    where prev_running_sum < tranche_sum
)
select
    m.tranche_doc_id,
    m.tranche_sum,
    'rule 1' as match_rule,
    m.tx_doc_id,
    m.tx_dt,
    m.tx_sum,
    m.ctrg_inn,
    m.ctrg_account
from matched_tx m
join rule1_matches r1
  on m.tranche_doc_id = r1.tranche_doc_id
 and m.tx_doc_id = r1.tx_doc_id
union all
select
    tranche_doc_id,
    tranche_sum,
    'rule 2' as match_rule,
    tx_doc_id,
    tx_dt,
    tx_sum,
    ctrg_inn,
    ctrg_account
from rule2_filtered
order by tranche_doc_id, tx_dt, tx_doc_id;
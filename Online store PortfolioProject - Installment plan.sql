/*
 The company
	an online store of mobile phones introduced a system of selling goods to customers using installment plan.

 Task
	develop two groups of reports (SQL queries) for contact center employees, containing necessary information:
	1. according to a specific contract, payments under it, arrears
		1.1 contract data report (info about client, product and contract details)
		1.2 report on payments under the contract (info about installment plan and made payments)
		1.3 a summary report on the amounts of payments and arrears under the contract 
	2. for all contracts for a certain period of time (general numbers for actual and finished installment plans)

Note: Column names are in quotation marks as ukraninan language was used before
*/


USE STORE_DATABASE

DECLARE @begin_date date
DECLARE @enddate_ip date
DECLARE @end_date date
DECLARE @count_date date
DECLARE @contract int
DECLARE @merchant int
DECLARE @monthly_payment int
DECLARE @report_date date
DECLARE @NEW_TABLE TABLE(Merchant_identifier int,Contract_identifier int,date_range date, m_payment int)


SET @merchant = 11 ---for 1.1, 1.2, 1.3
SET @contract = 2222 ---for 1.1, 1.2, 1.3
SET @report_date = '04.30.2020' -- for all

---------------------------------------------------------------------1.1-------------------------------------------------------------
SELECT   
	I.merchant_id AS 'Merchant_ID'
	,I.contract_number AS 'Contract_Number'
	,M.merchant_name AS 'Merchant_Name'
	,CL.client_name AS 'Client_Name'
	,B.Brand_name AS 'Brand_Name'
	,P.phone_name AS 'Phone_Name'
	,C.color_name AS 'Color_Name'
	,I.qu_inst AS 'NumberOf_installment_months'
	,I.inst AS 'Amount of the monthly payment (UAH)'
	,CONVERT(varchar,I.date_purch,104) AS 'Date of purchase/1st payment'
	,iif(DATEADD(mm,i.qu_inst-1,i.date_purch) <= @report_date, 
			I.qu_inst, 
			DATEDIFF(mm,DATEADD(mm,i.qu_inst-1,i.date_purch),@report_date)
			+I.qu_inst) AS 'NumInstPaymMustBePaid' -- Number of installments that must be paid paid on the last day of the current month
	,iif(DATEADD(mm,i.qu_inst-1,i.date_purch) <= @report_date, 
			I.qu_inst*I.inst, 
			(DATEDIFF(mm,DATEADD(mm,i.qu_inst-1,i.date_purch),@report_date)
			+I.qu_inst)*I.inst) AS 'AmountInstPaymMustBePaid' -- Installments amount that must be paid on the last day of the current month
FROM 
	installment_plan I
	LEFT JOIN merchants M ON I.merchant_id=M.merchant_id
	LEFT JOIN clients CL ON I.client_id=CL.client_id
	LEFT JOIN phones P ON I.phone_id=P.phone_id
	LEFT JOIN brands B ON P.brand_id=B.brand_id
	LEFT JOIN colors C ON I.color_id=C.color_id
WHERE 
	i.contract_number=@contract AND i.merchant_id=@merchant


---------------------------------------------------------------------1.2-------------------------------------------------------------

SELECT 
	@begin_date = date_purch
	,@enddate_ip  =DATEADD(mm,qu_inst-1,date_purch)
	,@end_date = (
				  SELECT 
						MAX(maxdate) 
				  FROM (
					    SELECT 
							Max(DATEADD(mm,qu_inst-1,date_purch)) AS 'maxdate'
					    FROM 
							installment_plan 
					    WHERE 
							contract_number=@contract AND	merchant_id=@merchant
					    UNION 
					    SELECT 
							max(date_payment) AS 'maxdate'
					    FROM 
							payments 
					    WHERE 
							contract_number=@contract AND MERCHANT_ID=@merchant
					    ) a
			     )
	,@monthly_payment=inst
		
FROM
	installment_plan
WHERE
	contract_number=@contract AND merchant_id=@merchant


SET @count_date=@begin_date
		WHILE @count_date<=@end_date
			BEGIN
				INSERT INTO @NEW_TABLE (Merchant_identifier, Contract_identifier, date_range, m_payment)
				VALUES (@merchant, @contract, @count_date,IIF(@count_date>@enddate_ip, 0, @monthly_payment))
				SET @count_date = DATEADD(MM, 1, @count_date)
			END

SELECT 
	n.Merchant_identifier AS 'Merchant_Ident'
	,n.Contract_identifier AS 'Contract_Ident'
	,YEAR(n.date_range) AS 'Year_of_installment_payment'
	,MONTH(n.date_range) AS 'Installment_payment_month' 
	,CASE 
		WHEN ROW_NUMBER() OVER (PARTITION BY MONTH(n.date_range),YEAR(n.date_range) ORDER BY n.date_range)=1 
		THEN m_payment 
		ELSE 0 
	END AS 'Monthly_installment_amount'  -- Must show only one record of fix monthly amount even if few payments are made during the same month
	,CONVERT(varchar,p.date_payment,104) AS 'Customer_payment_date'
	,ISNULL(p.payment,0) AS 'Customer_paid_amount'
FROM 
	@NEW_TABLE n
	 LEFT JOIN payments p ON n.Merchant_identifier=p.merchant_id 
							AND n.Contract_identifier=p.contract_number 
							AND (year(n.date_range)=YEAR(p.date_payment)
							AND MONTH(n.date_range)=month(p.date_payment))
ORDER BY 
	YEAR(n.date_range), MONTH(n.date_range)


---------------------------------------------------------------------1.3-------------------------------------------------------------
SELECT 
	i.merchant_id AS 'Merchant_ID'
	,i.contract_number AS 'Contract_Number'
	,i.inst*i.qu_inst AS 'AmountInstPaymMustBePaid'
	,a.sum_payment AS 'Customer_paid_amount'
	,i.inst*i.qu_inst-a.sum_payment AS 'Contract_balance_TOTAL'
	,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,
		i.inst*i.qu_inst,
		(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-a.sum_payment AS 'including_Debt'
FROM 
	installment_plan i 
	LEFt JOIN (
			   SELECT 
					i.merchant_id,i.contract_number
					,SUM(p.payment) AS 'sum_payment'
			   FROM 
					installment_plan i 
					LEFT JOIN payments p ON i.contract_number=p.contract_number 
											AND i.merchant_id=p.merchant_id
			   GROUP BY 
					i.merchant_id,i.contract_number
			   ) a
			ON i.contract_number=a.contract_number 
				AND i.merchant_id=a.merchant_id
WHERE 
	i.contract_number=@contract AND i.merchant_id=@merchant


--------------------------------------------------------------------- 2 -------------------------------------------------------------
SELECT
	contract_status AS 'Installment_period'
	,debt_status AS 'status_of_debt'
	,SUM(credit_summ) AS 'Installment_amount'
	,SUM(sum_mustbepain_on3004) AS 'Amount_mustbepaid_on_reportdate'
	,SUM(already_paid) AS 'Already_paid_on_reportdate'
	,COUNT(*) AS 'NumberOfClients'
	,SUM(sum_debt) AS 'Total-Debt'
	,SUM(left_pay_acc_contr) AS 'left_topay_w-out_debt'
	,SUM(zero_month_debt) AS '0 months' --The number of clients who overdue 0 monthly payments
	,SUM(one_month_debt) AS '1 month' --The number of clients who overdue 1 monthly payment
	,SUM(two_month_debt) AS '2 months' --The number of clients who overdue 2 monthly payments
	,SUM(three_month_debt) AS '3 months' --The number of clients who overdue 3 monthly payments
	,SUM(fourandmore_month_debt) AS '4 and more months' --The number of clients who overdue 4 and more monthly payments
	,SUM(zero_month_debt_amount) AS '0 months (amount)' -- Debt amount of customers who overdue 0 monthly payments
	,SUM(one_month_debt_amount) AS '1 month (amount)' -- Debt amount of customers who overdue 1 monthly payment
	,SUM(two_month_debt_amount) AS '2 months (amount)' -- Debt amount of customers who overdue 2 monthly payments
	,SUM(three_month_debt_amount) AS '3 months (amount)' -- Debt amount of customers who overdue 3 monthly payments
	,SUM(fourandmore_month_debt_amount) AS '4 and more months (amount)' -- Debt amount of customers who overdue 4 and more monthly payments


FROM
(
SELECT I.merchant_id AS 'merch_id'
		,I.contract_number AS 'contr_id'
		,CONVERT(VARCHAR,I.date_purch,104) AS 'date_purch'
		,I.qu_inst AS 'qu_monthly_pay'
		,I.inst AS 'amount_monthly_pay'
		,convert(varchar,dateadd(mm,I.qu_inst-1,I.date_purch),104) AS 'last_payment_date'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=0,1,0) AS 'zero_month_debt'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=1,1,0) AS 'one_month_debt'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=2,1,0) AS 'two_month_debt'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=3,1,0) AS 'three_month_debt'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment>=4,1,0) AS 'fourandmore_month_debt'
		,i.qu_inst*i.inst AS 'credit_summ'
		,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst) AS sum_mustbepain_on3004
		,p.t_pay AS 'already_paid'
		,iif((iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)<0,0
			,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay) AS 'sum_debt'
		,iif(DATEDIFF(mm,I.date_purch,@report_date)>=i.qu_inst,'Finished','Actual') AS 'contract_status'
		,iif(p.t_pay<iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)
			,'Have a debt','No debt') AS 'debt_status'
		,iif(DATEDIFF(mm,@report_date,dateadd(mm,I.qu_inst-1,I.date_purch))<0,0,DATEDIFF(mm,@report_date,dateadd(mm,I.qu_inst-1,I.date_purch)))*I.inst AS 'left_pay_acc_contr'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=0
			,(iif((iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)<0,0
			,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)) 
			,0) AS 'zero_month_debt_amount'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=1
			,(iif((iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)<0,0
			,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)) 
			,0) AS 'one_month_debt_amount'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=2
			,(iif((iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)<0,0
			,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)) 
			,0) AS 'two_month_debt_amount'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment=3
			,(iif((iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)<0,0
			,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)) 
			,0) AS 'three_month_debt_amount'
		,iif(iif(DATEADD(mm,I.qu_inst-1,I.date_purch) <= @report_date, I.qu_inst, DATEDIFF(mm,DATEADD(mm,I.qu_inst-1,I.date_purch),@report_date)+I.qu_inst)-B.num_of_payment>=4
			,(iif((iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)<0,0
			,iif(DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch))<=0,i.inst*i.qu_inst,(i.qu_inst-DATEDIFF(mm,@report_date,DATEADD(mm,i.qu_inst-1,i.date_purch)))*i.inst)-p.t_pay)) 
			,0) AS 'fourandmore_month_debt_amount'

		
FROM 
	installment_plan I
	LEFT JOIN (
				SELECT 
					A.merchant_id,A.contract_number,COUNT(A.UNIQ_YM) AS 'num_of_payment'
				FROM (
					  SELECT 
							p.merchant_id
							,p.contract_number
							, CONCAT(YEAR(P.date_payment),month(P.date_payment)) AS 'UNIQ_YM'
					  FROM
						payments p 
						LEFT JOIN (
								   SELECT 
										merchant_id, contract_number, date_purch, qu_inst, inst
										,DATEADD(mm,qu_inst-1,date_purch) AS 'last_payment_date'
										,IIF(DATEADD(mm,qu_inst-1,date_purch) <= @report_date, 
												qu_inst,
												DATEDIFF(mm,DATEADD(mm,qu_inst-1,date_purch),
												@report_date)+qu_inst) AS 'qu_mandatory_payments'
								   FROM
										installment_plan
								   ) i 
								ON p.merchant_id=i.merchant_id 
								AND p.contract_number=i.contract_number
					  WHERE
						  EOmonth(p.date_payment)<=EOmonth(i.last_payment_date)
					  GROUP BY
						  p.merchant_id,
						  p.contract_number,
						  CONCAT (YEAR(P.date_payment),month(P.date_payment))
					  ) A
				GROUP BY 
					A.merchant_id,A.contract_number
				) B
				ON I.merchant_id=B.merchant_id AND I.contract_number=B.contract_number

	LEFT JOIN (
			   SELECT 
					merchant_id,contract_number,SUM(payment) AS 't_pay'
			   FROM 
					payments
			   GROUP BY 
					merchant_id,contract_number
			   ) p 
			   ON I.merchant_id=p.merchant_id AND I.contract_number=p.contract_number
	) A
GROUP BY 
	contract_status, debt_status

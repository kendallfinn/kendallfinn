/*
*
*	Name:  Denials_Prod_All.sql
*
*	Purpose:  This query is the source for the Denials received for the last 3 months.
*				This is a list of the denied trips with the refence data points for the required analysis.
*				See additional comments in the SQL below.
*
*	Version History:
*	Version		Name				Date		Revision Description
*	1.0			K. Finnigsmier		20240622	Created for Denials process conversion from MS Access db to SQL Server
*   1.1		    K. Finnigsmier		20240925	Added State, and PBT Insurance Code for Date of Death reporting
*
*/
CREATE OR ALTER VIEW [dbo].[vw_Denials_Prod_Trips_All]
(
[FE Code]
, [FE Name]
, [Trip Number]
, [Patient Last Name]
, [Patient First Name]
, [Member Number]
, [Date of Service]
, [Billed Date]
, [Denial Date]
, [Denial Source Code]
, [Insurance Name]
, [Collection Plan Code]
, [Financial Class Combo]
, [LOB Combo]
, [Division]
, [State]
, [Business Unit Combo]
, [Billing Region]
, [Billing Team]
, [Modifier1]
, [Total Denial Amt]
, [Denial Code]
, [Denial Description]
, [Denial Type Code]
, [Denial Type Description]
, [Denial User Posted]
, [Denial Source Area]
, [Emergency]
, [Denial Category]
, [Addressable]
, [Avoidable]
, [Soft/Hard Denial]
, [PBTInsuranceCombo]
, [PBTInsuranceGroupCombo]
)
as
with CTE_FIRST_ROW as (
-- This query gets the information from the first record for the trip from the RODE file that have been loaded to the REPORTING_TABLE_DETIALS table for the last 12 months.
-- Information on the subsequent records for each trip in the RODE file are not required for the analysis.
-- The procedure information and Allowable Amount is the only data that changes in each set of trip records. Procedure info and Allowance Amt are excluded so we can use the first record for each trip.
select * from
(
select ROW_NUMBER() over (partition by [Trip Number] order by [Denial Date], [Procedure Line Number], [Denial Amount], [Allowable Amount]) as ROW, *
  FROM [AMR_REV].[dbo].[REPORTING_TABLE_DENIALS]
) t
where t.[ROW] = 1
),
CTE_Total_Amts as (
-- This first query totals the amounts for each trip from the Denials RODE file that have been loaded to the REPORTING_TABLE_DETIALS table for the last 12 months.
-- It is appropriate to total all of the amounts from each set of trip records to get the correct amounts for analysis.
select [Trip Number], sum([Denial Amount]) as [Total_Denial_Amt]
FROM (
select distinct [FE Code], [LOB Code], [Division Code], [Trip Number], [Date of Service], [Billed Date], [Denial Date], [Procedure Line Number], [Procedure Line Code], [Trip Line Level Indicator],
[Denial Code], [Denial Type Code], [Denial Source Code], [Collection Plan Code], [Denial Amount]
from [AMR_REV].[dbo].[REPORTING_TABLE_DENIALS]
) x
group by x.[Trip Number]
)
--,
--DENIAL_BASE as (
-- This query creates the single record for each trip using the first record for each trip and the total of the amounts from all the records for each trip.
-- The requisite reference tables are jointed to the facts from the REPORTING_TABLE_DENIALS to group the records for further analysis.
-- As of this first version, 1.0, the reference tables are static. No automated process is in place to refresh the data.
select a.[FE Code]
, z.[FinancialEntityName]
, a.[Trip Number]
, a.[Patient Last Name]
, a.[Patient First Name]
, a.[Member Number]
, a.[Date of Service]
, a.[Billed Date]
, a.[Denial Date]
, a.[Denial Source Code]
, g.[INSURANCE_NAME]
, a.[Collection Plan Code]
, z.PBTFinancialClassCombo
, z.[Line of Business Combo]
, z.Division
, z.StateCode
, z.BusinessUnitCombo
, z.BillingRegion
, z.PodsGrouping
, z.Modifier1Combo
, b.[Total_Denial_Amt]
, a.[Denial Code]
, a.[Denial Description]
, a.[Denial Type Code]
, a.[Denial Type Description]
, a.[Denial User Posted]
, c.[Source Area]
, a.[Emergency]
, upper(ISNULL(c.[CATEGORY],'Other'))
, c.[Create Denial Record]
, c.[Avoidable vs Unavoidable]
, c.[Soft Denial vs Hard Denial]
, z.PBTInsuranceCombo
, z.PBTInsuranceGroupCombo
from CTE_FIRST_ROW a
join CTE_Total_Amts b on a.[Trip Number] = b.[Trip Number]
left outer join [AMR_REV].[dbo].[ic_Denials_Master_Reference] c on a.[FE Code] = c.FE and a.[Denial Code] = c.[Denial Code]
left outer join [AMR_REV].[dbo].[vw_AMR_REV_2019+] z on a.[Trip Number] = z.TripNumber
left outer join [AMR_REV].[dbo].[ic_ref_insurance] g on a.[Denial Source Code] = g.[INSURANCE_CODE] and a.[FE Code] = g.[FE]
where [Denial Date] >= DATEADD(month,-3,EOMONTH(GETDATE()))
;
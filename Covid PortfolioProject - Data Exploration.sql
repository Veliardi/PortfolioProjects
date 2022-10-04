-- COVID 19  Data Exploration

SELECT
	*
FROM
	PortfolioProject..dataDeaths$
WHERE
	continent IS NOT NULL
ORDER BY
	3,4



-- Total Cases vs Total Deaths (selected countries)

SELECT
	location, date, total_cases, total_deaths
	,ROUND((total_deaths/total_cases)*100,2) AS DeathPercentage
FROM
	PortfolioProject..dataDeaths$
WHERE
	location IN ('ukraine','poland','estonia','latvia','lithuania','united states','united kingdom')
ORDER BY 
	location, date



-- Total Cases vs Population (showing percentage of infected with Covid)

SELECT
	location, date, population, total_cases
	,ROUND((total_cases/population)*100,2) AS CasesPercentage
FROM
	PortfolioProject..dataDeaths$

ORDER BY 
	location, date



-- Countries with the Highest Infection Rate compared to Population

SELECT
	location, population
	,MAX(total_cases) AS HighestInfectionCount
	,ROUND(MAX(total_cases/population)*100,2) AS HighestCasesPercentage 
FROM
	PortfolioProject..dataDeaths$
GROUP BY
	location, population
ORDER BY
	HighestCasesPercentage DESC



-- Countries with Highest Death Count per Population

SELECT
	location
	,MAX(CAST(total_deaths as int)) AS HighestDeathCount
FROM
	PortfolioProject..dataDeaths$
WHERE
	continent IS NOT NULL
GROUP BY
	location
ORDER BY
	HighestDeathCount DESC



-- Highest Death Count by continent

SELECT
	continent
	,MAX(CAST(total_deaths as int)) AS HighestDeathCount
FROM
	PortfolioProject..dataDeaths$
WHERE
	continent IS NOT NULL
GROUP BY
	continent
ORDER BY
	HighestDeathCount DESC



-- WORLD NUMBERS

SELECT
	SUM(new_cases) AS TotalCases
	,SUM(CONVERT(bigint,new_deaths)) AS TotalDeath
	,ROUND(SUM(CONVERT(bigint,new_deaths))/SUM(new_cases)*100,2) AS DeathPercentage
FROM
	PortfolioProject..dataDeaths$
WHERE
	continent IS NOT NULL



--- Total Cases, Total Death, Death Percentage by income

SELECT
	location
	,SUM(new_cases) AS TotalCases
	,SUM(CONVERT(bigint,new_deaths)) AS TotalDeath
	,ROUND(SUM(CONVERT(bigint,new_deaths))/SUM(new_cases)*100,2) AS DeathPercentage
FROM 
	PortfolioProject..dataDeaths$
WHERE
	continent IS NULL AND location like '%income'
GROUP BY
	location



-- Total Population vs Vaccinations Percentage

SELECT 
	continent
	,location
	,population
	, ISNULL(ROUND(CAST(people_vac as float)/population*100,2),0) as vac_perc
	, ISNULL(ROUND(CAST(people_fully_vac as float)/population*100,2),0) as full_vac_perc
	, ISNULL(ROUND(CAST(total_boost as float)/population*100,2),0) as boost_vac_perc
FROM
	(
	SELECT
		v.continent, v.location
		, max(cast(d.population as bigint)) AS population
		, MAX(cast(v.people_vaccinated as bigint)) AS people_vac
		, MAX(cast(v.people_fully_vaccinated as bigint)) AS people_fully_vac
		, MAX(cast(v.total_boosters as bigint)) AS total_boost
	FROM 
		PortfolioProject..dataVaccinations$ V
		JOIN PortfolioProject..dataDeaths$ D
		ON v.location=d.location
		AND v.date=d.date
	WHERE
		v.continent IS NOT NULL
	GROUP BY
		v.continent, v.location
	) vn --vaccinations number
ORDER BY 
	continent,location



-- Temp Table

DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
	(
	Continent nvarchar(255),
	Location nvarchar(255),
	Population numeric,
	Vaccination_percent float,
	Full_Vaccination_percent float,
	Boost_Vaccination_percent float
	)

	
INSERT INTO #PercentPopulationVaccinated
SELECT 
	continent
	,location
	,population
	, ISNULL(ROUND(CAST(people_vac as float)/population*100,2),0) as vac_perc
	, ISNULL(ROUND(CAST(people_fully_vac as float)/population*100,2),0) as full_vac_perc
	, ISNULL(ROUND(CAST(total_boost as float)/population*100,2),0) as boost_vac_perc
FROM
	(
	SELECT
		v.continent, v.location
		, max(cast(d.population as bigint)) AS population
		, MAX(cast(v.people_vaccinated as bigint)) AS people_vac
		, MAX(cast(v.people_fully_vaccinated as bigint)) AS people_fully_vac
		, MAX(cast(v.total_boosters as bigint)) AS total_boost
	FROM 
		PortfolioProject..dataVaccinations$ V
		JOIN PortfolioProject..dataDeaths$ D
		ON v.location=d.location
		AND v.date=d.date
	WHERE
		v.continent IS NOT NULL AND population IS NOT NULL
	GROUP BY
		v.continent, v.location
	) vn --vaccinations number


SELECT *
FROM #PercentPopulationVaccinated




-- Vaccination Dynamic (new vaccinations by date)
	
DROP TABLE IF EXISTS NewVaccinationsDynamic
CREATE TABLE NewVaccinationsDynamic
	(
	Continent nvarchar(255),
	Location nvarchar(255),
	date datetime,
	people_vaccinated numeric,
	new_vacc numeric,
	)

INSERT INTO NewVaccinationsDynamic
	SELECT
		continent, location, date
		,people_vaccinated
		,ISNULL((CAST(people_vaccinated as int)-LAG(people_vaccinated) OVER(PARTITION BY location ORDER BY location,date)),people_vaccinated) as new_vacc
	FROM
		PortfolioProject..dataVaccinations$ 
	WHERE
		continent IS NOT NULL and people_vaccinated IS NOT NULL
	ORDER BY 
		location, date



DROP TABLE IF EXISTS NewFullVaccinationsDynamic
CREATE TABLE NewFullVaccinationsDynamic
	(
	Continent nvarchar(255),
	Location nvarchar(255),
	date datetime,
	people_fully_vaccinated numeric,
	new_full_vacc numeric,
	)

INSERT INTO NewFullVaccinationsDynamic
	SELECT
		continent, location, date
		,people_fully_vaccinated
		,ISNULL((CAST(people_fully_vaccinated as int)-LAG(people_fully_vaccinated) OVER(PARTITION BY location ORDER BY location,date)),people_fully_vaccinated) as new_full_vacc
	FROM
		PortfolioProject..dataVaccinations$ 
	WHERE
		continent IS NOT NULL and people_fully_vaccinated IS NOT NULL
	ORDER BY 
		location, date



DROP TABLE IF EXISTS NewBoostVaccinationsDynamic
CREATE TABLE NewBoostVaccinationsDynamic
	(
	Continent nvarchar(255),
	Location nvarchar(255),
	date datetime,
	total_boosters numeric,
	new_boost_vacc numeric,
	)

INSERT INTO NewBoostVaccinationsDynamic
	SELECT
		continent, location, date
		,total_boosters
		,ISNULL((CAST(total_boosters as int)-LAG(total_boosters) OVER(PARTITION BY location ORDER BY location,date)),total_boosters) as new_boost_vacc
	FROM
		PortfolioProject..dataVaccinations$ 
	WHERE
		continent IS NOT NULL and total_boosters IS NOT NULL
	ORDER BY 
		location, date

SELECT * FROM NewVaccinationsDynamic WHERE location in ('china','united states', 'ukraine','poland') ORDER BY location,date
SELECT * FROM NewFullVaccinationsDynamic WHERE location in ('china','united states','ukraine','poland') ORDER BY location,date
SELECT * FROM NewBoostVaccinationsDynamic WHERE location in ('china','united states','ukraine','poland') ORDER BY location,date



-- Creating View to store data for later visualizations

CREATE VIEW VaccinationsDynamic AS
SELECT
	v.continent
	,v.location
	,v.date
	,nvd.new_vacc
	,nfvd.new_full_vacc
	,nbvd.new_boost_vacc
FROM 
	PortfolioProject..dataVaccinations$  V
	LEFT JOIN NewVaccinationsDynamic nvd ON v.location=nvd.Location AND v.date=nvd.date
	LEFT JOIN NewFullVaccinationsDynamic nfvd ON v.location=nfvd.Location AND v.date=nfvd.date
	LEFT JOIN NewBoostVaccinationsDynamic nbvd ON v.location=nbvd.Location AND v.date=nbvd.date
WHERE 
	v.continent IS NOT NULL
--ORDER BY
--	v.location, v.date




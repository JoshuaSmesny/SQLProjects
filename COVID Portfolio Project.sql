-- Beginning analysis over two excel files containing covid related information (deaths and vaccinations)

USE covidfile;

-- Check covid_deaths tables information

SHOW COLUMNS FROM covid_deaths; 

-- Check covid_vaccs table information since we will be joining it later for further exploration

SELECT * 
FROM covid_vaccs;

SHOW COLUMNS FROM covid_vaccs; 

SELECT * 
FROM covid_deaths;

-- Checking for population change over the dataset period

SELECT location, MAX(population) - MIN(population) AS difference
FROM covid_deaths
GROUP BY location;

-- For this data set we have Asia, Africa, North America, South America and Europe as continents

SELECT TRIM(continent), MAX(CAST(total_deaths AS UNSIGNED)) AS total_deaths
FROM covid_deaths
GROUP BY continent;

-- Curious test to check percentage of smokers related to covid deaths for men and women

SELECT continent, AVG(female_smokers), AVG(male_smokers) 
FROM covid_deaths
GROUP BY continent
ORDER BY AVG(male_smokers) DESC;

-- Select the Data that we are going to be using

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM covid_deaths
ORDER BY location;

-- Looking at Total Cases vs Total Deaths
-- For this date range Mexico peaked at over a 12% fatility rate if contracted

SELECT location, date, total_cases, total_deaths, ROUND(total_deaths / total_cases * 100, 2) AS DeathPercentage
FROM covid_deaths
WHERE location LIKE '%mexico%'
ORDER BY location; 

-- Checking what percentage of each location contracted covid over time
SELECT location, date, total_cases, population, ROUND(total_cases / population * 100, 2) AS PercentageContracted
FROM covid_deaths
ORDER BY location; 

-- Checking what percentage of Mexico's population contracted Covid at some point during this period

SELECT location, date, total_cases, population, ROUND(total_cases / population * 100, 2) AS PercentageContracted
FROM covid_deaths
WHERE location LIKE '%mexico%'
ORDER BY location; 

-- What country has the highest infection rate compared to population amongst data entered?

SELECT location, MAX(population) AS max_population, MAX(total_cases) AS highest_infection_count, MAX(total_cases/population)* 100 AS infection_rate
FROM covid_deaths
GROUP BY location
ORDER BY infection_rate DESC;

-- What country has the highest death rate compared to population amongst data entered?

SELECT location, MAX(population) AS max_population, MAX(total_deaths) AS covid_deaths, ROUND(MAX(total_deaths/population)* 100,3) AS death_rate_percentage
FROM covid_deaths
GROUP BY location
ORDER BY death_rate_percentage DESC;

-- What country has the most deaths amongst data entered?

SELECT location, MAX(population) AS max_population, MAX(CAST(total_deaths AS UNSIGNED)) AS covid_deaths, ROUND(MAX(total_deaths/population)* 100,3) AS death_rate
FROM covid_deaths
GROUP BY location
ORDER BY covid_deaths DESC;

-- GLOBAL NUMBERS

-- Comparing total cases to total deaths chronologically

SELECT date, SUM(new_cases) AS total_cases, SUM(CAST(new_deaths AS SIGNED)) AS total_deaths,
SUM(CAST(new_deaths AS SIGNED))/SUM(new_cases)*100 AS death_rate_percentage
FROM covid_deaths
GROUP BY date;

-- Doing a day-by-day comparison of new deaths to new cases

SELECT 
    date,
    SUM(new_cases) AS total_new_cases,
    SUM(CAST(new_deaths AS SIGNED)) AS total_deaths,
    SUM(CAST(new_deaths AS SIGNED)) / SUM(new_cases) * 100  AS death_percentage_this_day
FROM covid_deaths
GROUP BY date;

-- Using JOIN table from here to compare deaths to various parts of vaccination information

-- Looking at Total Population vs Vaccinations 

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations AS SIGNED)) OVER (PARTITION BY dea.location ORDER BY dea.location , dea.date) AS rolling_people_vaccinated
FROM covid_deaths dea
JOIN covid_vacc vac ON dea.location = vac.location
AND dea.date = vac.date
WHERE vac.new_vaccinations > 0;

-- Using diabetes_prevalence to see how it impacted chances of catching and dying from covid compared to 

-- write a query that looks at diabetes prevalence vs death percentage by country and try to see correlation

SELECT vac.location, vac.diabetes_prevalence, MAX(dea.total_deaths / dea.population) * 100 AS death_percentage
FROM covid_vacc vac
JOIN covid_deaths dea 
ON vac.date = dea.date AND vac.location = dea.location
GROUP BY vac.location, vac.diabetes_prevalence
ORDER BY death_percentage DESC
LIMIT 5;

-- Top 5 in order in terms of death_percentage from Covid : Bosnia Colombia Bolivia Belize Costa Rica

SELECT vac.location, vac.diabetes_prevalence, MAX(dea.total_deaths / dea.population) * 100 AS death_percentage
FROM covid_vacc vac
JOIN covid_deaths dea 
ON vac.date = dea.date AND vac.location = dea.location
GROUP BY vac.location, vac.diabetes_prevalence
ORDER BY diabetes_prevalence DESC;

-- 4 of our top 5 from death_percentage appear in the top 10 highest diabetes_prevalence countries

CREATE VIEW DiabetesVsDeathPercentage 
AS 
SELECT vac.location, vac.diabetes_prevalence, MAX(dea.total_deaths / dea.population) * 100 AS death_percentage
FROM covid_vacc vac
JOIN covid_deaths dea 
ON vac.date = dea.date AND vac.location = dea.location
GROUP BY vac.location, vac.diabetes_prevalence
ORDER BY diabetes_prevalence DESC; 

-- Created a view of the prior query to import into Tableau

SELECT *
FROM DiabetesVsDeathPercentage;

-- USE CTE so that we can have rolling_people_vaccinated as a part of our function for our rolling_percentage_vaccinated column

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, Rolling_People_Vaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations AS SIGNED)) OVER (PARTITION BY dea.location ORDER BY dea.location , dea.date) AS rolling_people_vaccinated
FROM covid_deaths dea
JOIN covid_vacc vac ON dea.location = vac.location
AND dea.date = vac.date
WHERE vac.new_vaccinations > 0
)

SELECT *, (Rolling_People_vaccinated / Population) * 100 AS Rolling_Percentage_Vaccinated
FROM PopvsVac;

-- TEMP TABLE ALTERNATIVE TEST 

CREATE TEMPORARY TABLE PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date nvarchar(255),
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
);

INSERT INTO PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations AS SIGNED)) OVER (PARTITION BY dea.location ORDER BY dea.location , dea.date) AS rolling_people_vaccinated
FROM covid_deaths dea
JOIN covid_vacc vac ON dea.location = vac.location
AND dea.date = vac.date
WHERE vac.new_vaccinations > 0;

SELECT *
FROM PercentPopulationVaccinated;

-- Creating a View to store data for Data Visualization in Tableau later on

CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations AS SIGNED)) OVER (PARTITION BY dea.location ORDER BY dea.location , dea.date) AS rolling_people_vaccinated
FROM covid_deaths dea
JOIN covid_vacc vac ON dea.location = vac.location
AND dea.date = vac.date
WHERE vac.new_vaccinations > 0;

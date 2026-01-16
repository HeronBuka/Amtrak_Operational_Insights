USE BUDT703_Project_0506_06

-- 1. Which host railroads (Amtrak vs. Non-Amtrak) have the best on-time performance
-- and what are the total routes, average of OTP and change in OTP from 2021 to 2023 for each category?
SELECT
	CASE
		WHEN r.routeHostRailroad LIKE '%Amtrak%' THEN 'Amtrak'
		ELSE 'Non-Amtrak'
		END AS 'Host Railroad Group',
	COUNT(DISTINCT r.routeId) AS 'Count of RouteId',
	AVG(ro.routeOTP) AS 'Average OTP',
	AVG(CASE WHEN ro.routeYear = 'FY23' THEN ro.routeOTP ELSE NULL END) -
	AVG(CASE WHEN ro.routeYear = 'FY22' THEN ro.routeOTP ELSE NULL END) AS 'Change in OTP (2022-2023)',
	AVG(CASE WHEN ro.routeYear = 'FY22' THEN ro.routeOTP ELSE NULL END) -
	AVG(CASE WHEN ro.routeYear = 'FY21' THEN ro.routeOTP ELSE NULL END) AS 'Change in OTP (2021-2022)'
FROM [OnTrack.Route] r
JOIN [OnTrack.Route_OTP] ro ON ro.routeId = r.routeId
GROUP BY 
	CASE
		WHEN r.routeHostRailroad LIKE '%Amtrak%' THEN 'Amtrak'
		ELSE 'Non-Amtrak'
	END
ORDER BY 'Average OTP' DESC;

-- 2.Which are the top 10 stations with the highest total budget
-- and what is the average On-Time Performance (OTP) of the routes that serve these stations?
WITH RankedStations AS (
	SELECT 
		s1.stationCode,
		s1.stationName,
       	SUM(b.budgetTotal) AS TotalBudget,
		RANK() OVER (ORDER BY SUM(b.budgetTotal) DESC) AS Rank
	FROM [OnTrack.Station] s1
	JOIN [OnTrack.Budget] b ON s1.stationCode = b.stationCode
	GROUP BY s1.stationCode, s1.stationName)
SELECT 
	RS.stationCode AS 'Station Code',
	RS.stationName AS 'Station Name',
	RS.TotalBudget AS 'Total Budget',
	AVG(ro.routeOTP) AS 'Average OTP'
FROM RankedStations RS
JOIN [OnTrack.Serve] sv ON RS.stationCode = sv.stationCode
JOIN [OnTrack.Route_OTP] ro ON sv.routeId = ro.routeId
WHERE RS.Rank <= 10
GROUP BY RS.stationCode, RS.stationName, RS.TotalBudget
ORDER BY RS.TotalBudget DESC;

-- 3.What are the top 10 stations with the highest number of routes
-- and how do they perform in terms of average OTP?
WITH StationRoutesRanking AS (
	SELECT
		s.stationCode,
		s.stationState,
		s.stationCity,
		COUNT(DISTINCT r.routeId) AS TotalRoutes,
		AVG(ro.routeOTP) AS AverageOTP   
	FROM [OnTrack.Station] s
		JOIN [OnTrack.Serve] sv ON sv.stationCode = s.stationCode
		JOIN [OnTrack.Route] r ON r.routeId = sv.routeId
		JOIN [OnTrack.Route_OTP] ro ON ro.routeId = r.routeId
	GROUP BY s.stationCode, s.stationState, s.stationCity),
	RankedStations AS (
	SELECT *,
		RANK() OVER (ORDER BY TotalRoutes DESC) AS Rank
	FROM StationRoutesRanking)
SELECT
	stationCode AS 'Station Code',
	stationState AS 'Station State',
	stationCity AS 'Station City',
	TotalRoutes AS 'Total Routes',
	AverageOTP AS 'Average OPT'
FROM RankedStations
WHERE Rank <= 10
ORDER BY 'Total Routes' DESC; 

-- 4.What are the top 10 stations with the highest total ridership
-- and how do they perform in terms of budget allocation efficiency (allocation per ridership) 
-- and what is the average on-time performance (OTP) of the routes serving these stations?
WITH StationRidership AS (
SELECT s.stationCode, s.stationName,
		SUM(rd.ridershipQuantity) AS totalRidership
    FROM [OnTrack.Station] s
	JOIN [OnTrack.Ridership] rd ON s.stationCode = rd.stationCode
    GROUP BY s.stationCode, s.stationName),
StationBudget AS (
    SELECT s.stationCode, s.stationName,
		SUM(b.budgetTotal) AS totalBudget
    FROM [OnTrack.Station] s
	JOIN [OnTrack.Budget] b ON s.stationCode = b.stationCode
	GROUP BY s.stationCode, s.stationName),
RankedStations AS (
	SELECT sr.stationCode, sr.stationName, sr.totalRidership, sb.totalBudget,
		RANK() OVER (ORDER BY sr.totalRidership DESC) AS Rank
	FROM StationRidership sr
	JOIN StationBudget sb ON sr.stationCode = sb.stationCode)
SELECT rs.stationCode AS 'Station Code',
	rs.stationName AS 'Station Name',
	rs.totalRidership AS 'Total Riderships',
	ROUND(rs.totalBudget / NULLIF(rs.totalRidership, 0), 2) AS 'Allocation Per Rider',
	AVG(ro.routeOTP) AS 'Avg. Route OTP'
FROM RankedStations rs
JOIN [OnTrack.Serve] sv ON rs.stationCode = sv.stationCode
JOIN [OnTrack.Route_OTP] ro ON sv.routeId = ro.routeId
WHERE rs.Rank <= 10
GROUP BY rs.stationCode, rs.stationName, rs.totalRidership, rs.totalBudget
ORDER BY rs.totalRidership DESC;

-- 5.How can we calculate the FY23 average on-time performance (Average OTP FY23) 
-- for different route types (Long Distance, State Supported, Northeast Corridor) grouped by state?
SELECT 
 	s.stationState,
AVG(o.routeOTP) AS 'Avg OTP of FY23',
	r.routeType AS 'Route Type'
FROM [OnTrack.Station] s
JOIN [OnTrack.Serve] sv ON s.stationCode = sv.stationCode
JOIN [OnTrack.Route] r ON sv.routeId = r.routeId
JOIN [OnTrack.Route_OTP] o ON r.routeId = o.routeId
WHERE o.routeYear='FY23'
GROUP BY stationState, r.routeType
ORDER BY s.stationState

-- 6.What are the details of each route, including the route name, type, host railroad, total frequency
-- and on-time performance metrics (average, minimum, and maximum OTP), sorted by average OTP in descending order?
SELECT
	r.routeName AS 'Route Name',
	r.routeType AS 'Route Type',
	r.routeHostRailroad AS 'Route Host Railroad',
	COALESCE(FORMAT(SUM(r.routeFrequency),''), 'No Value') AS 'Route Frequency',
	AVG(o.routeOTP) AS 'Avg. Route OTP',
	MIN(o.routeOTP) AS 'Min OTP',
	MAX(o.routeOTP) AS 'Max OTP'
FROM [OnTrack.Route] r
	JOIN [OnTrack.Route_OTP] o ON r.routeId = o.routeId
GROUP BY r.routeName, r.routeType, r.routeHostRailroad, r.routeFrequency
ORDER BY 'Avg. Route OTP' DESC;







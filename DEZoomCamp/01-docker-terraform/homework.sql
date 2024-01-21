	//Q3.
	SELECT 
        count(*) 
	FROM public."Green" 
	WHERE CAST(lpep_pickup_datetime AS DATE) = '20190918' AND CAST(lpep_dropoff_datetime AS DATE) = '20190918'

	//Q4.
	SELECT 
        CAST(lpep_pickup_datetime AS DATE), max(trip_distance) 
	FROM public."Green" 
	WHERE  1=1
	GROUP BY CAST(lpep_pickup_datetime AS DATE)
	ORDER by max(trip_distance) desc

	//Q5.
	SELECT 
		zpu."Borough",
		SUM(total_amount)
	FROM public."Green" g 
	INNER JOIN public."Zones" zpu
		ON g."PULocationID" = zpu."LocationID" 
		AND zpu."Borough" != 'Unknown'	
	WHERE 1=1
		AND CAST(lpep_pickup_datetime AS DATE) = '20190918'
	GROUP BY zpu."Borough"

	//Q6.
	SELECT 
		zdo."Zone",
		MAX(tip_amount)
	FROM public."Green" g 
	INNER JOIN public."Zones" zpu
		ON g."PULocationID" = zpu."LocationID" 
		AND zpu."Zone" = 'Astoria'
	INNER JOIN public."Zones" zdo
		ON g."DOLocationID" = zdo."LocationID"	
	WHERE 1=1
		AND CAST(lpep_pickup_datetime AS DATE) >= '20190901'
		AND CAST(lpep_pickup_datetime AS DATE) <= '20190930'	
	GROUP BY zdo."Zone"
	ORDER BY MAX(tip_amount) desc

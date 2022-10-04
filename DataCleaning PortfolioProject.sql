/*
Cleaning Data in SQL Queries
*/

----- Standardize Date Format

ALTER TABLE PortfolioProject..NashvilleHousing
Add SaleDateConverted Date

UPDATE PortfolioProject..NashvilleHousing
SET SaleDateConverted=CONVERT(date,SaleDate)

SELECT 
	SaleDate, SaleDateConverted
FROM 
	PortfolioProject..NashvilleHousing



-----  Populate Property Address data

SELECT
	a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress
	,ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM 
	PortfolioProject..NashvilleHousing a
	JOIN PortfolioProject..NashvilleHousing b
		ON a.ParcelID=b.ParcelID
		AND a.[UniqueID ]<>b.[UniqueID ] 
WHERE
	a.PropertyAddress IS NULL


UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress,b.PropertyAddress)
FROM 
	PortfolioProject..NashvilleHousing a
	JOIN PortfolioProject..NashvilleHousing b
		ON a.ParcelID=b.ParcelID
		AND a.[UniqueID ]<>b.[UniqueID ] 
WHERE
	a.PropertyAddress IS NULL


-----  Breaking out Address into Individual Columns (Address, City, State)

SELECT 
	PropertyAddress
	,SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1) AS 'AddressSplit'
	,SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress)+1, LEN(PropertyAddress)) AS 'CitySplit'
FROM
	PortfolioProject..NashvilleHousing


ALTER TABLE PortfolioProject..NashvilleHousing
Add PropertySplitAddress nvarchar(255)

ALTER TABLE PortfolioProject..NashvilleHousing
Add PropertySplitCity nvarchar(255)

UPDATE PortfolioProject..NashvilleHousing
SET PropertySplitAddress= SUBSTRING(PropertyAddress,1,CHARINDEX(',',PropertyAddress)-1)

UPDATE PortfolioProject..NashvilleHousing
SET PropertySplitCity= SUBSTRING(PropertyAddress,CHARINDEX(',',PropertyAddress)+1, LEN(PropertyAddress))



----- PARSENAME to split Owner address
SELECT
	PARSENAME(REPLACE(OwnerAddress, ',', '.'),3) 
	,PARSENAME(REPLACE(OwnerAddress, ',', '.'),2) 
	,PARSENAME(REPLACE(OwnerAddress, ',', '.'),1) 
FROM
	PortfolioProject..NashvilleHousing


ALTER TABLE PortfolioProject..NashvilleHousing
Add OwnerSplitAddress nvarchar(255)

ALTER TABLE PortfolioProject..NashvilleHousing
Add OwnerSplitCity nvarchar(255)

ALTER TABLE PortfolioProject..NashvilleHousing
Add OwnerSplitState nvarchar(255)

UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'),3)

UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'),2)

UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'),1)


SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant)
FROM PortfolioProject..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2

SELECT
	SoldAsVacant
	,CASE
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	 END
FROM 
	PortfolioProject..NashvilleHousing

UPDATE NashvilleHousing
SET SoldAsVacant = CASE	
					  WHEN SoldAsVacant = 'Y' THEN 'Yes' 
					  WHEN SoldAsVacant = 'N' THEN 'No' 
					  ELSE SoldAsVacant
				   END



----- Remove Duplicates

DROP TABLE IF EXISTS NashvilleHousingNEW
SELECT *, ROW_NUMBER() OVER(PARTITION BY ParcelID,	PropertyAddress,SalePrice,SaleDate,LegalReference ORDER BY UniqueID) as row_num
INTO NashvilleHousingNEW --creating new table where unused columns and duplicates will be removed
FROM PortfolioProject.dbo.NashvilleHousing

DELETE FROM NashvilleHousingNEW WHERE row_num >1


----- Delete Unused Columns

ALTER TABLE NashvilleHousingNEW
	DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress,SaleDate

SELECT *
FROM NashvilleHousingNEW
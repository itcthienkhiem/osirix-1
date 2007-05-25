/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/




#define id Id

#include "itkMultiThreader.h"
#include "itkImage.h"
#include "itkMesh.h"
#include "itkImportImageFilter.h"
#include "itkConnectedThresholdImageFilter.h"
#include "itkNeighborhoodConnectedImageFilter.h"
#include "itkConfidenceConnectedImageFilter.h"
#include "itkCurvatureFlowImageFilter.h"
#include "itkCastImageFilter.h"
#include "itkBinaryMaskToNarrowBandPointSetFilter.h"
//#include "itkBinaryMask3DMeshSource.h"
#include "itkVTKImageExport.h"
#include "itkVTKImageExportBase.h"

#include "itkSignedDanielssonDistanceMapImageFilter.h"
#include "itkApproximateSignedDistanceMapImageFilter.h"
//#include "itkSignedMaurerDistanceMapImageFilter.h"




#include "vtkImageImport.h"
#include "vtkMarchingSquares.h"
#include "vtkPolyData.h"
#include "vtkCleanPolyData.h"
#include "vtkPolyDataConnectivityFilter.h"
#include "vtkCell.h"
#include "vtkContourFilter.h"
#include "vtkImageData.h"

#undef id

#import "ViewerController.h"
#import "WaitRendering.h"
#import "DCMPix.h"
#import "DCMView.h"
#import "ROI.h"
#import "MyPoint.h"
#import "OSIPoint3D.h"

#import "ITKSegmentation3D.h"

/**
 * This function will connect the given itk::VTKImageExport filter to
 * the given vtkImageImport filter.
 */
template <typename ITK_Exporter, typename VTK_Importer>
void ConnectPipelines(ITK_Exporter exporter, VTK_Importer* importer)
{
  importer->SetUpdateInformationCallback(exporter->GetUpdateInformationCallback());
  importer->SetPipelineModifiedCallback(exporter->GetPipelineModifiedCallback());
  importer->SetWholeExtentCallback(exporter->GetWholeExtentCallback());
  importer->SetSpacingCallback(exporter->GetSpacingCallback());
  importer->SetOriginCallback(exporter->GetOriginCallback());
  importer->SetScalarTypeCallback(exporter->GetScalarTypeCallback());
  importer->SetNumberOfComponentsCallback(exporter->GetNumberOfComponentsCallback());
  importer->SetPropagateUpdateExtentCallback(exporter->GetPropagateUpdateExtentCallback());
  importer->SetUpdateDataCallback(exporter->GetUpdateDataCallback());
  importer->SetDataExtentCallback(exporter->GetDataExtentCallback());
  importer->SetBufferPointerCallback(exporter->GetBufferPointerCallback());
  importer->SetCallbackUserData(exporter->GetCallbackUserData());
}

//template <typename VTK_Exporter, typename ITK_Importer>
//void ConnectPipelines(VTK_Exporter* exporter, ITK_Importer importer)
//{
//  importer->SetUpdateInformationCallback(exporter->GetUpdateInformationCallback());
//  importer->SetPipelineModifiedCallback(exporter->GetPipelineModifiedCallback());
//  importer->SetWholeExtentCallback(exporter->GetWholeExtentCallback());
//  importer->SetSpacingCallback(exporter->GetSpacingCallback());
//  importer->SetOriginCallback(exporter->GetOriginCallback());
//  importer->SetScalarTypeCallback(exporter->GetScalarTypeCallback());
//  importer->SetNumberOfComponentsCallback(exporter->GetNumberOfComponentsCallback());
//  importer->SetPropagateUpdateExtentCallback(exporter->GetPropagateUpdateExtentCallback());
//  importer->SetUpdateDataCallback(exporter->GetUpdateDataCallback());
//  importer->SetDataExtentCallback(exporter->GetDataExtentCallback());
//  importer->SetBufferPointerCallback(exporter->GetBufferPointerCallback());
//  importer->SetCallbackUserData(exporter->GetCallbackUserData());
//}

@implementation ITKSegmentation3D

+ (NSArray*) fastGrowingRegionWithVolume: (float*) volume width:(long) w height:(long) h depth:(long) depth seedPoint:(long*) seed from:(float) from pixList:(NSArray*) pixList
{
	BOOL					found = YES, foundPlane = YES;
	long					minX, minY, minZ, maxX, maxY, maxZ;
	long					nminX, nminY, nminZ, nmaxX, nmaxY, nmaxZ;
	long					x, y, z, zz, s = w*h;
	float					*srcPtrZ, *srcPtrY, *srcPtrX;
	unsigned char			*rPtr, *rPtrZ, *rPtrY, *rPtrX;
	NSMutableArray			*roiList = [NSMutableArray array];
	
	if( seed[ 0] <= 1) seed[ 0] = 2;	if( seed[ 0] >= w - 2)		seed[ 0] = w - 3;
	if( seed[ 1] <= 1) seed[ 1] = 2;	if( seed[ 1] >= h - 2)		seed[ 1] = h - 3;
	if( seed[ 2] <= 1) seed[ 2] = 2;	if( seed[ 2] >= depth - 2)	seed[ 2] = depth - 3;
	
	minX = seed[ 0]-1;		maxX = seed[ 0]+2;
	minY = seed[ 1]-1;		maxY = seed[ 1]+2;
	minZ = seed[ 2];		maxZ = seed[ 2]+1;

	rPtr = (unsigned char*) calloc( w*h*depth, sizeof(unsigned char));
	if( rPtr)
	{
		rPtr[ seed[ 0]+1 + seed[ 1]*w + seed[ 2]*s] = 0xFE;
		
		while( found)
		{
			found = NO;
			
			if( minX <= 0) minX = 1;	if( maxX >= w - 1)		maxX = w - 1;
			if( minY <= 0) minY = 1;	if( maxY >= h - 1)		maxY = h - 1;
			if( minZ <= 0) minZ = 1;	if( maxZ >= depth - 1)	maxZ = depth - 1;
			
//			srcPtrZ = volume + minZ*s;
//			rPtrZ = rPtr + minZ*s;
			
			long addZ = maxZ-minZ-1;
			if( addZ == 0) addZ++;
			
			for( z = minZ; z < maxZ; z += addZ)
			{
				foundPlane = YES;
				while( foundPlane)
				{
					if( minX <= 0) minX = 1;	if( maxX >= w - 1)		maxX = w - 1;
					if( minY <= 0) minY = 1;	if( maxY >= h - 1)		maxY = h - 1;
					if( minZ <= 0) minZ = 1;	if( maxZ >= depth - 1)	maxZ = depth - 1;
					
					rPtrZ = rPtr + z*s;
					srcPtrZ = volume + z*s;

					foundPlane = NO;
					srcPtrY = srcPtrZ + minY*w  + minX;
					rPtrY = rPtrZ + minY*w  + minX;
					y = maxY-minY;
					while( y-- > 0)
					{
						srcPtrX = srcPtrY;
						rPtrX = rPtrY;
						
						x = maxX-minX;
						while( x-- > 0)
						{
							if( *rPtrX == 0xFE)
							{
								*rPtrX = 0xFF;
								
								if( *(rPtrX+1) == 0) if(	*(srcPtrX+1) > from) {	*(rPtrX+1) = 0xFE;}	else *(rPtrX+1) = 2;
								if( *(rPtrX-1) == 0) if(	*(srcPtrX-1) > from) {	*(rPtrX-1) = 0xFE;}	else *(rPtrX-1) = 2;
								if( *(rPtrX+w) == 0) if(	*(srcPtrX+w) > from) {	*(rPtrX+w) = 0xFE;}	else *(rPtrX+w) = 2;
								if( *(rPtrX-w) == 0) if(	*(srcPtrX-w) > from) {	*(rPtrX-w) = 0xFE;}	else *(rPtrX-w) = 2;
								
								foundPlane = YES;
							}
							rPtrX++;
							srcPtrX++;
						}
						
						srcPtrY+= w;
						rPtrY += w;
					}
					
					// Should we grow the box?
					if( foundPlane)
					{
						found = YES;
						
						nminX	=	minX;		nmaxX	=	maxX;
						nminY	=	minY;		nmaxY	=	maxY;
						
						// X plane
						
						rPtrZ = rPtr + minX + minZ*s;
						for( zz = minZ; zz < maxZ; zz++, rPtrZ += s)
						{
							for( y = minY; y < maxY; y++)
							{
								if( rPtrZ[ y*w])
								{
									nminX = minX -1;
									zz = maxZ;
								}
							}
						}
						
						rPtrZ = rPtr + maxX-1  + minZ*s;
						for( zz = minZ; zz < maxZ; zz++, rPtrZ += s)
						{
							for( y = minY; y < maxY; y++)
							{
								if( rPtrZ[ y*w])
								{
									nmaxX = maxX + 1;
									zz = maxZ;
								}
							}
						}
						
						// Y plane
						
						rPtrZ = rPtr + minY*w + minZ*s;
						for( zz = minZ; zz < maxZ; zz++, rPtrZ += s)
						{
							for( x = minX; x < maxX; x++)
							{
								if( rPtrZ[ x])
								{
									nminY = minY - 1;
									zz = maxZ;
								}
							}
						}
						
						rPtrZ = rPtr + (maxY-1)*w  + minZ*s;
						for( zz = minZ; zz < maxZ; zz++, rPtrZ += s)
						{
							for( x = minX; x < maxX; x++)
							{
								if( rPtrZ[ x])
								{
									nmaxY = maxY + 1;
									zz = maxZ;
								}
							}
						}
						
						minX	=	nminX;		maxX	=	nmaxX;
						minY	=	nminY;		maxY	=	nmaxY;
					}
				}
				
				rPtrZ = rPtr + z*s;
				srcPtrZ = volume + z*s;

				srcPtrY = srcPtrZ + minY*w + minX;
				rPtrY = rPtrZ + minY*w + minX;
				y = maxY-minY;
				while( y-- > 0)
				{
					srcPtrX = srcPtrY;
					rPtrX = rPtrY;
					
					x = maxX-minX;
					while( x-- > 0)
					{
						if( *rPtrX == 0xFF)
						{
							if( *(rPtrX-s) == 0) if(	*(srcPtrX-s) > from) {	*(rPtrX-s) = 0xFE;}	else *(rPtrX-s) = 2;
							if( *(rPtrX+s) == 0) if(	*(srcPtrX+s) > from) {	*(rPtrX+s) = 0xFE;}	else *(rPtrX+s) = 2;
						}
						rPtrX++;
						srcPtrX++;
					}
					
					srcPtrY += w;
					rPtrY += w;
				}
			}
			
			if( found)
			{
				nminZ	=	minZ;		nmaxZ	=	maxZ;

				// Z plane
				rPtrZ = rPtr + minZ*s + minY*w;
				for( y = minY; y < maxY; y++, rPtrZ += w)
				{
					for( x = minX; x < maxX; x++)
					{
						if( rPtrZ[ x])
						{
							nminZ = minZ-1;
							y = maxY;
						}
					}
				}
				
				rPtrZ = rPtr + (maxZ-1)*s + minY*w;
				for( y = minY; y < maxY; y++, rPtrZ += w)
				{
					for( x = minX; x < maxX; x++)
					{
						if( rPtrZ[ x])
						{
							nmaxZ = maxZ +1;
							y = maxY;
						}
					}
				}
				
				minZ	=	nminZ;		maxZ	=	nmaxZ;
			}
		}

		long i;
		
		
		rPtrZ = rPtr;
		for( i = 0; i < [pixList count]; i++)
		{
			int buffHeight = [[pixList objectAtIndex: i] pheight];
			int buffWidth = [[pixList objectAtIndex: i] pwidth];
			
			ROI *theNewROI = [[ROI alloc]	initWithTexture:rPtrZ
											textWidth:w
											textHeight:h
											textName: @"BoneRemovalAlgorithmROIUniqueName"
											positionX:0
											positionY:0
											spacingX:[[pixList objectAtIndex: i] pixelSpacingX]
											spacingY:[[pixList objectAtIndex: i] pixelSpacingY]
											imageOrigin:NSMakePoint([[pixList objectAtIndex: i] originX], [[pixList objectAtIndex: i] originY])];
			if( [theNewROI reduceTextureIfPossible] == NO)	// NO means that the ROI is NOT empty
			{
				[roiList addObject: [NSDictionary dictionaryWithObjectsAndKeys: theNewROI, @"roi", [pixList objectAtIndex: i], @"curPix", 0L]];
//				[[roiList objectAtIndex:i] addObject:theNewROI];		// roiList
//				[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:theNewROI userInfo: 0L];	
//				[theNewROI setROIMode: ROI_selected];
//				[[NSNotificationCenter defaultCenter] postNotificationName: @"roiSelected" object:theNewROI userInfo: nil];
			}
			[theNewROI release];
			
			rPtrZ+= w*h;
		}
		
		free( rPtr);
	}
	
	return roiList;
}

+ (NSMutableArray*) extractContour:(unsigned char*) map width:(long) width height:(long) height numPoints:(long) numPoints
{
	itk::MultiThreader::SetGlobalDefaultNumberOfThreads( MPProcessors());
	
	NSMutableArray	*tempArray = [NSMutableArray arrayWithCapacity:0];
	int				dataExtent[ 6];
	
	vtkImageImport*	image2D = vtkImageImport::New();
	image2D->SetWholeExtent(0, width-1, 0, height-1, 0, 0);
	image2D->SetDataExtentToWholeExtent();
	image2D->SetDataScalarTypeToUnsignedChar();
	image2D->SetImportVoidPointer(map);
	
	
//	vtkContourFilter*		isoContour = vtkContourFilter::New();
	vtkMarchingSquares*		isoContour = vtkMarchingSquares::New();
//	isoContour->SetNumberOfContours( 1);
	
	isoContour->SetValue(0, 1);
	isoContour->SetInput( (vtkDataObject*) image2D->GetOutput());
	isoContour->Update();

	image2D->GetDataExtent( dataExtent);
//	NSLog(@"%d, %d, %d, %d, %d, %d", dataExtent[0], dataExtent[1], dataExtent[2], dataExtent[3], dataExtent[4], dataExtent[5]);
				
	vtkPolyDataConnectivityFilter	*filter = vtkPolyDataConnectivityFilter::New();
				
	filter->SetColorRegions( 1);
	filter->SetExtractionModeToLargestRegion();
				
	filter->SetInput( isoContour->GetOutput());
	vtkPolyData *output = filter->GetOutput();
	output->Update();
	
//	NSLog( @"Extracted region: %d", filter->GetNumberOfExtractedRegions());
//	NSLog( @"Lines: %d Polys: %d, Points: %d", output->GetNumberOfLines(), output->GetNumberOfPolys(), output->GetNumberOfPoints());
	
	if( output->GetNumberOfLines() > 3)
	{
		long	ii;
		
		for( ii = 0; ii < output->GetNumberOfLines(); ii+=2)
		{
			double *  p = output->GetPoint(ii);
			[tempArray addObject: [MyPoint point: NSMakePoint(p[0], p[1])]];		//[srcViewer newPoint: p[0]  : p[1] ]];
		}
		
		ii--;
		
		if(ii>= output->GetNumberOfLines()) ii-=2;
		
		for( ; ii >= 0; ii-=2)
		{
			double *  p = output->GetPoint(ii);
			[tempArray addObject: [MyPoint point: NSMakePoint(p[0], p[1])]];
		}
		
		long roiResolution = 1;
		
		if( [tempArray count] > numPoints)
		{
			long newroiResolution = [tempArray count] / numPoints;
			
			newroiResolution++;
			
			if( newroiResolution >  roiResolution) roiResolution = newroiResolution;
		}
		
		if( roiResolution != 1)
		{
			long tot = [tempArray count];
			long zz;
			
			for( ii = tot-1; ii >= 0; ii -= roiResolution)
			{
				for( zz = 0; zz < roiResolution-1; zz++)
				{
					if( [tempArray count] > 3 && ii-zz >= 0) [tempArray removeObjectAtIndex: ii-zz];
				}
			}
		}
	}
	
	isoContour->Delete();
	filter->Delete();
	image2D->Delete();
	
	return tempArray;
}

+ (NSMutableArray*) extractContour:(unsigned char*) map width:(long) width height:(long) height
{
   [self extractContour:map width:width height:height numPoints: 100];
}
-(void) dealloc
{
	[itkImage dealloc];
	
	[super dealloc];
}

/*
- (void)finalize {
	//nothing to do does not need to be called
}
*/

- (id) initWith :(NSMutableArray*) pix :(float*) volumeData :(long) slice {
	return [self initWithPix :(NSMutableArray*) pix volume:(float*) volumeData  slice:(long) slice resampleData:NO];
}

- (id) initWithPix :(NSMutableArray*) pix volume:(float*) volumeData  slice:(long) slice resampleData:(BOOL)resampleData
{
    if (self = [super init])
	{
		itk::MultiThreader::SetGlobalDefaultNumberOfThreads( MPProcessors());
		_resampledData = resampleData;
		NSLog(@"slice ID: %d", slice);
		itkImage = [[ITK alloc] initWithPix :(NSMutableArray*) pix volume:(float*) volumeData sliceCount:(long) slice resampleData:(BOOL)resampleData];
		//itkImage = [[ITK alloc] initWith: pix :volumeData :slice];
    }
    return self;
}



- (void) regionGrowing3D:(ViewerController*) srcViewer :(ViewerController*) destViewer :(long) slice :(NSPoint) startingPoint :(int) algorithmNumber :(NSArray*) parameters :(BOOL) setIn :(float) inValue :(BOOL) setOut :(float) outValue :(int) roiType :(long) roiResolution :(NSString*) newname;
{
	NSLog(@"ITK max number of threads: %d", itk::MultiThreader::GetGlobalDefaultNumberOfThreads());
	
	// Input image
	typedef float InternalPixelType;
	typedef itk::Image< InternalPixelType, 3 > InternalImageType; 
	// Char Output image
	typedef unsigned char OutputPixelType;
	typedef itk::Image< OutputPixelType, 3 > OutputImageType;
	// Type Caster
	typedef itk::CastImageFilter< InternalImageType, OutputImageType > CastingFilterType;
	CastingFilterType::Pointer caster = CastingFilterType::New();
	
	// STARTING POINT
	InternalImageType::IndexType  index;
	index[0] = (long) startingPoint.x;
	index[1] = (long) startingPoint.y;
	if( slice == -1) index[2] = [[srcViewer imageView] curImage];
	else index[2] = 0;

	//FILTERS
	typedef itk::ConnectedThresholdImageFilter< InternalImageType, InternalImageType > ConnectedThresholdFilterType;
	typedef itk::NeighborhoodConnectedImageFilter< InternalImageType, InternalImageType > NeighborhoodConnectedFilterType;
	typedef itk::ConfidenceConnectedImageFilter< InternalImageType, InternalImageType > ConfidenceConnectedFilterType;
	
	ConnectedThresholdFilterType::Pointer thresholdFilter = 0L;
	NeighborhoodConnectedFilterType::Pointer neighborhoodFilter = 0L;
	ConfidenceConnectedFilterType::Pointer confidenceFilter = 0L;
	// connected threshold filter
	if (algorithmNumber==0 || algorithmNumber==1)
	{
		thresholdFilter = ConnectedThresholdFilterType::New();
		
		float loV, upV;
		if (algorithmNumber==0)
		{
			long xpx, ypx;
			xpx = (long)startingPoint.x;
			ypx = (long)startingPoint.y;
			NSLog(@"xpx : %d, ypx: %d", xpx, ypx);
			float mouseValue = [[[srcViewer imageView] curDCM] getPixelValueX:(long)startingPoint.x Y:(long)startingPoint.y];
			float interval = [[parameters objectAtIndex:0] floatValue];
			loV = mouseValue - interval/2.0;
			upV = mouseValue + interval/2.0;
			NSLog(@"startingPoint.x : %f, startingPoint.y: %f", startingPoint.x, startingPoint.y);
			NSLog(@"mouseValue : %f, loV: %f, upV: %f", mouseValue, loV, upV);
		}
		else if (algorithmNumber==1)
		{
			loV = [[parameters objectAtIndex:0] floatValue];
			upV = [[parameters objectAtIndex:1] floatValue];
		}
		
		thresholdFilter->SetLower(loV);
		thresholdFilter->SetUpper(upV);
		thresholdFilter->SetReplaceValue(255);
	
		thresholdFilter->SetSeed(index);
		thresholdFilter->SetInput([itkImage itkImporter]->GetOutput());
		caster->SetInput(thresholdFilter->GetOutput());	// <- FLOAT TO CHAR
	}
	// Neighbor Connected filter
	else if (algorithmNumber==2)
	{
		neighborhoodFilter = NeighborhoodConnectedFilterType::New();
		
		float loV, upV;
		loV = [[parameters objectAtIndex:0] floatValue];
		upV = [[parameters objectAtIndex:1] floatValue];
		neighborhoodFilter->SetLower(loV);
		neighborhoodFilter->SetUpper(upV);
		
		InternalImageType::SizeType radius;
		radius[0] = [[parameters objectAtIndex:2] intValue];
		radius[1] = [[parameters objectAtIndex:2] intValue];
		// masu 2006-07-19 radius[2] was undefinied -> crash!
		radius[2] = [[parameters objectAtIndex:2] intValue];
		// masu end
		neighborhoodFilter->SetRadius(radius);
		
		neighborhoodFilter->SetReplaceValue(255);
		neighborhoodFilter->SetSeed(index);
		neighborhoodFilter->SetInput([itkImage itkImporter]->GetOutput());
		caster->SetInput(neighborhoodFilter->GetOutput());	// <- FLOAT TO CHAR
	}
	// Confidence Connected filter
	else if (algorithmNumber==3)
	{
		confidenceFilter = ConfidenceConnectedFilterType::New();
		
		float multiplier = [[parameters objectAtIndex:0] floatValue];
		confidenceFilter->SetMultiplier(multiplier);
		int numberOfIterations = [[parameters objectAtIndex:1] intValue];
		confidenceFilter->SetNumberOfIterations(numberOfIterations);
		int radius = [[parameters objectAtIndex:1] intValue];
		confidenceFilter->SetInitialNeighborhoodRadius(radius);
		
		confidenceFilter->SetReplaceValue(255);
		confidenceFilter->SetSeed(index);
		confidenceFilter->SetInput([itkImage itkImporter]->GetOutput());
		caster->SetInput(confidenceFilter->GetOutput());	// <- FLOAT TO CHAR
	}

	WaitRendering	*wait = 0L;
	
	if( slice == -1) wait = [[WaitRendering alloc] init: NSLocalizedString(@"Propagating Region...", 0L)];
	[wait showWindow:self];
	
	NSLog(@"RegionGrowing starts...");
	
	try
	{
		caster->Update();
	}
	catch( itk::ExceptionObject & excep )
	{
		NSLog(@"RegionGrowing failed...");
	}
	
	NSLog(@"Done...");
	
	[wait setString: NSLocalizedString(@"Preparing Results...",@"Preparing Results...")];
	
	// PRODUCE A NEW SERIES
	if( destViewer)
	{
		long	i, x, y, z;
		float	*dstImage, *srcImage;
		long	startSlice, endSlice;
		
		if( slice == -1)
		{
			startSlice = 0;
			endSlice = [[destViewer pixList] count];
		}
		else
		{
			startSlice = slice;
			endSlice = startSlice+1;
		}
		
		for( i = startSlice; i < endSlice; i++)
		{
			ImageType::IndexType pixelIndex; 
			DCMPix	*curPix = [[destViewer pixList] objectAtIndex: i];
			dstImage = [curPix fImage];
			srcImage = [[[srcViewer pixList] objectAtIndex: i] fImage];
			
			if(slice == -1) pixelIndex[2] = i; // z position
			else pixelIndex[2] = 0; // z position
			
			for( y = 0; y < [curPix pheight]; y++) 
			{
				pixelIndex[1] = y; // y position
				for( x = 0; x < [curPix pwidth]; x++) 
				{
					pixelIndex[0] = x; // x position
					
					if( caster->GetOutput()->GetPixel( pixelIndex) == 255)
					{
						if( setIn)
						{
							*dstImage = inValue;
						}
						else
						{
							*dstImage = *srcImage;
						}
					}
					
					dstImage++;
					srcImage++;
				}
			}
		}
	}
	// PRODUCE A ROI ON THE ORIGINAL SERIES
	// ROI type = tPlain
	else if (roiType == tPlain)
	{
		if( slice == -1)
		{			
			unsigned char *buff = caster->GetOutput()->GetBufferPointer();
			
		//	[srcViewer addRoiFromFullStackBuffer:buff withName:newname];
			
			long		i;
			for( i = 0; i < [[srcViewer pixList] count]; i++)
			{
				int buffHeight = [[[srcViewer pixList] objectAtIndex: i] pheight];
				int buffWidth = [[[srcViewer pixList] objectAtIndex: i] pwidth];
				
				ROI *theNewROI = [[ROI alloc]	initWithTexture:buff
												textWidth:buffWidth
												textHeight:buffHeight
												textName:newname
												positionX:0
												positionY:0
												spacingX:[[[srcViewer imageView] curDCM] pixelSpacingX]
												spacingY:[[[srcViewer imageView] curDCM] pixelSpacingY]
												imageOrigin:NSMakePoint([[[srcViewer imageView] curDCM] originX], [[[srcViewer imageView] curDCM] originY])];
				if( [theNewROI reduceTextureIfPossible] == NO)	// NO means that the ROI is NOT empty
				{
					[[[srcViewer roiList] objectAtIndex:i] addObject:theNewROI];
					[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:theNewROI userInfo: 0L];	
					[theNewROI setROIMode: ROI_selected];
					[[NSNotificationCenter defaultCenter] postNotificationName: @"roiSelected" object:theNewROI userInfo: nil];
				}
				[theNewROI setSliceThickness:[[[srcViewer imageView] curDCM] sliceThickness]];
				[theNewROI release];
				
				buff+= buffHeight*buffWidth;
			}
		}
		else
		{
			// result of the segmentation will only contain one slice.
			unsigned char *buff = caster->GetOutput()->GetBufferPointer();

			int buffHeight = [[[srcViewer pixList] objectAtIndex: 0] pheight];
			int buffWidth = [[[srcViewer pixList] objectAtIndex: 0] pwidth];

			ROI *theNewROI = [[ROI alloc]	initWithTexture:buff
											textWidth:buffWidth
											textHeight:buffHeight
											textName:newname
											positionX:0
											positionY:0
											spacingX:[[[srcViewer imageView] curDCM] pixelSpacingX]
											spacingY:[[[srcViewer imageView] curDCM] pixelSpacingY]
											imageOrigin:NSMakePoint([[[srcViewer imageView] curDCM] originX], [[[srcViewer imageView] curDCM] originY])];
			[theNewROI reduceTextureIfPossible];
			[theNewROI setSliceThickness:[[[srcViewer imageView] curDCM] sliceThickness]];
			[[[srcViewer roiList] objectAtIndex:slice] addObject:theNewROI];
			[[NSNotificationCenter defaultCenter] postNotificationName: @"roiChange" object:theNewROI userInfo: 0L];	
			[theNewROI setROIMode: ROI_selected];
			[[NSNotificationCenter defaultCenter] postNotificationName: @"roiSelected" object:theNewROI userInfo: nil];
			
			[theNewROI release];
		}
		[srcViewer needsDisplayUpdate];
	}
	// PRODUCE A ROI ON THE ORIGINAL SERIES
	// ROI type = tPolygon
	else
	{
		long	i, x, y, z;
		long	startSlice, endSlice;
		OutputImageType::Pointer frameImage = caster->GetOutput();
		
		
		frameImage->Update();
		
		if( slice == -1)
		{
			startSlice = 0;
			endSlice = [[srcViewer pixList] count];
		}
		else
		{
			startSlice = slice;
			endSlice = startSlice+1;
		}

		//------------------------------------------------------------------------
		// ITK to VTK pipeline connection.
		//------------------------------------------------------------------------

		typedef itk::VTKImageExport<OutputImageType> ImageExportType;

		// Create the itk::VTKImageExport instance and connect it to the
		// itk::CurvatureFlowImageFilter.
		ImageExportType::Pointer itkExporter = ImageExportType::New();
		itkExporter->SetInput( frameImage);

		// Create the vtkImageImport and connect it to the
		// itk::VTKImageExport instance.
		vtkImageImport* vtkImporter = vtkImageImport::New();
		ConnectPipelines(itkExporter, vtkImporter);
		vtkImporter->Update();
		
		int dataExtent[ 6];
		vtkImporter->GetDataExtent( dataExtent);
				
		for( i = startSlice; i < endSlice; i++)
		{
			long			imageSize = (dataExtent[ 1]+1) * (dataExtent[ 3]+1);
			unsigned char	*image2Ddata = (unsigned char*) malloc( imageSize), *tempPtr;
			vtkImageImport	*image2D;
			DCMPix			*curPix = [[srcViewer pixList] objectAtIndex: i];
			
			if( slice == -1)
				memcpy( image2Ddata, ((unsigned char*) vtkImporter->GetOutput()->GetScalarPointer()) + (i * imageSize), imageSize);
			else
				memcpy( image2Ddata, ((unsigned char*) vtkImporter->GetOutput()->GetScalarPointer()), imageSize);

			image2D = vtkImageImport::New();
			image2D->SetWholeExtent(0, dataExtent[ 1], 0, dataExtent[ 3], 0, 0);
			image2D->SetDataExtentToWholeExtent();
			image2D->SetDataScalarTypeToUnsignedChar();
			image2D->SetImportVoidPointer(image2Ddata);		
			
			tempPtr = image2Ddata;
			for( x = 0; x < [curPix pwidth]; x++) 
			{
				tempPtr[ x] = 0;
			}
			tempPtr = image2Ddata + ([curPix pwidth]) * ([curPix pheight]-1);
			for( x = 0; x < [curPix pwidth]; x++) 
			{
				tempPtr[ x] = 0;
			}
			tempPtr = image2Ddata;
			for( x = 0; x < [curPix pheight]; x++) 
			{
				*tempPtr = 0;
				tempPtr += [curPix pwidth];
			}
			tempPtr = image2Ddata + [curPix pwidth]-1;
			for( x = 0; x < [curPix pheight]; x++) 
			{
				*tempPtr = 0;
				tempPtr += [curPix pwidth];
			}
			
			{
				//------------------------------------------------------------------------
				// VTK MARCHING SQUARE
				//------------------------------------------------------------------------
				
				int dataExtent[ 6];
				vtkImporter->GetDataExtent( dataExtent);
			//	NSLog(@"%d, %d, %d, %d", dataExtent[0], dataExtent[1], dataExtent[2], dataExtent[3]);
				
//				if( slice == -1)
//				{
//					isoContour->SetImageRange(dataExtent[0], dataExtent[1], dataExtent[2], dataExtent[3], i, i);
//				}
				
				vtkContourFilter*		isoContour = vtkContourFilter::New();
			//	vtkMarchingSquares*		isoContour = vtkMarchingSquares::New();
				
				isoContour->SetValue(0, 1);
				isoContour->SetInput( (vtkDataObject*) image2D->GetOutput());
				isoContour->Update();

				image2D->GetDataExtent( dataExtent);
				NSLog(@"%d, %d, %d, %d, %d, %d", dataExtent[0], dataExtent[1], dataExtent[2], dataExtent[3], dataExtent[4], dataExtent[5]);
				
				vtkPolyDataConnectivityFilter	*filter = vtkPolyDataConnectivityFilter::New();
				
				filter->SetColorRegions( 1);
				filter->SetExtractionModeToLargestRegion();
				
				filter->SetInput( isoContour->GetOutput());
				vtkPolyData *output = filter->GetOutput();
				
	//			filter->SetExtractionModeToAllRegions();
	//			filter->Update();
	//			filter->SetExtractionModeToSpecifiedRegions();
	//
	//			for (int i=0; i<filter->GetNumberOfExtractedRegions(); i++)
	//			{
	//				filter->AddSpecifiedRegion(i);
	//				filter->Update();
	//				
	//				output = filter->GetOutput();
	//				NSLog( @"%d", filter->GetOutput()->GetNumberOfPolys());
	////				NSLog( @"Region 0: %d", cells->GetNumberOfPoints());
	//				NSLog( @"Lines: %d Polys: %d, Points: %d, Cells: %d - %d - %d", output->GetNumberOfLines(), output->GetNumberOfPolys(), output->GetNumberOfPoints(), output->GetNumberOfCells(), output->GetNumberOfStrips(), output->GetNumberOfVerts());
	//
	//				// if region shall be dropped
	//				filter->DeleteSpecifiedRegion(i);
	//			}
				
				output->Update();
				NSLog( @"Extracted region: %d", filter->GetNumberOfExtractedRegions());
				
				NSLog( @"Lines: %d Polys: %d, Points: %d", output->GetNumberOfLines(), output->GetNumberOfPolys(), output->GetNumberOfPoints());
				
				if( output->GetNumberOfLines() > 3)
				{
					long			ii;
					ROI				*newROI = [srcViewer newROI: tCPolygon];
					NSMutableArray  *points = [newROI points];
					float	resolX, resolY;
					
			//		resolX = [[[srcViewer pixList] objectAtIndex: 0] pixelSpacingX]; // along X direction
			//		resolY = [[[srcViewer pixList] objectAtIndex: 0] pixelSpacingY]; // along Y direction
					
					for( ii = 0; ii < output->GetNumberOfLines(); ii+=2)
					{
						double *  p = output->GetPoint(ii);
						[points addObject: [srcViewer newPoint: p[0]  : p[1] ]];
					}
					ii--;
					if(ii>= output->GetNumberOfLines()) ii-=2;
					for( ; ii >= 0; ii-=2)
					{
						double *  p = output->GetPoint(ii);
						[points addObject: [srcViewer newPoint: p[0]  : p[1] ]];
					}
					
					#define MAXPOINTS 200
					
					if( [points count] > MAXPOINTS)
					{
						long newroiResolution = [points count] / MAXPOINTS;
						
						newroiResolution++;
						
						if( newroiResolution >  roiResolution) roiResolution = newroiResolution;
					}
					
					if( roiResolution != 1)
					{
						long tot = [points count];
						long zz;
						
						for( ii = tot-1; ii >= 0; ii -= roiResolution)
						{
							for( zz = 0; zz < roiResolution-1; zz++)
							{
								if( [points count] > 3 && ii-zz >= 0) [points removeObjectAtIndex: ii-zz];
							}
						}
					}
	
					{
					NSMutableArray  *roiSeriesList;
					NSMutableArray  *roiImageList;

					roiSeriesList = [srcViewer roiList];
					
					if( slice == -1) roiImageList = [roiSeriesList objectAtIndex: i];
					else roiImageList = [roiSeriesList objectAtIndex: [[srcViewer imageView] curImage]];
					
					[newROI setName: newname];
					[roiImageList addObject: newROI];
					[srcViewer needsDisplayUpdate];
					}
				}
				
				isoContour->Delete();
				filter->Delete();
			}
			
			image2D->Delete();
			free( image2Ddata);
		}
		
		vtkImporter->Delete();
	}
	
	[wait close];
	[wait release];
}


- (void)endoscopySegmentationForViewer:(ViewerController*) srcViewer seeds:(NSArray *)seeds {
	// Setup 
	//#define UseApproximateSignedDistanceMapImageFilter
	DCMPix *curPix = [[srcViewer imageView] curDCM];
	long minSize = 2;
	long x,y,z;
	long width = (int)[curPix pwidth];
	long height = (int)[curPix pheight];
	long depth = (int)[[srcViewer pixList] count];
	
	if (_resampledData) {
		width /=2;
		height/=2;
		depth /=2;
	}
		
	NSLog(@"width %d height %d depth: %d", width,height,depth);
	long w = width - minSize;
	long h = height - minSize;
	long d = depth - minSize;
	float maxDistance = 3;
	long sliceSize = width * height; 

		// Fllat Pixel Type
	typedef float FloatPixelType;
	typedef itk::Image< FloatPixelType, 3 > FloatImageType; 
	// Char Output image
	typedef unsigned char CharPixelType;
	typedef itk::Image< CharPixelType, 3 > CharImageType;
	// signed Char Output image
	typedef signed char SignedCharPixelType;
	typedef itk::Image< SignedCharPixelType, 3 > SignedCharImageType;
	//Short image type
	typedef signed short SSPixelType;
	typedef itk::Image< SSPixelType, 3 > SSImageType;
	// Type distance Filter
	//typedef itk::SignedMaurerDistanceMapImageFilter< CharImageType, SSImageType  > DistanceMapType;
	typedef itk::SignedDanielssonDistanceMapImageFilter< CharImageType, SSImageType  > DistanceMapType;
	DistanceMapType::Pointer distanceMapFilter = DistanceMapType::New();
	distanceMapFilter->InsideIsPositiveOn ();
	
	typedef itk::ApproximateSignedDistanceMapImageFilter< CharImageType, FloatImageType  > ApproximateDistanceMapType;
	ApproximateDistanceMapType::Pointer approximateDistanceMapFilter = ApproximateDistanceMapType::New();
	approximateDistanceMapFilter->SetInsideValue(0.0);
	approximateDistanceMapFilter->SetOutsideValue(255.0);
	



	NSLog(@"start Endoscopy segmentation");

	//Segmentation Filter
	typedef itk::ConnectedThresholdImageFilter<FloatImageType, CharImageType > ConnectedThresholdFilterType;	
	ConnectedThresholdFilterType::Pointer thresholdFilter = 0L;
	
	// create filter
	thresholdFilter = ConnectedThresholdFilterType::New();
			
	thresholdFilter->SetLower(-2000.0);
	thresholdFilter->SetUpper(-150.0);
	thresholdFilter->SetReplaceValue(255.0);


	NSEnumerator *enumerator = [seeds objectEnumerator];
	id seed;
	//Add seed points. Can use more than 1
	
	while (seed = [enumerator nextObject]) {
		FloatImageType::IndexType  index;
		if (_resampledData){
			index[0] = (long) [seed x] / 2;
			index[1] = (long) [seed y] / 2;
			index[2] = (long) [seed z] / 2;
		}
		else{
			index[0] = (long) [seed x];
			index[1] = (long) [seed y];
			index[2] = (long) [seed z];
		}
		NSLog(@"Seed x = %d  y = %d  z = %d", index[0], index[1], index[2]);
		thresholdFilter->AddSeed(index);
	}
	
	// make connections Inputs and outputs
	//resampleFilter->SetInput([itkImage itkImporter]->GetOutput());
	thresholdFilter->SetInput([itkImage itkImporter]->GetOutput());
	distanceMapFilter->SetInput(thresholdFilter->GetOutput());	
	approximateDistanceMapFilter->SetInput(thresholdFilter->GetOutput());	
		WaitRendering	*wait = 0L;
	
	wait = [[WaitRendering alloc] init: NSLocalizedString(@"Propagating Region...", 0L)];
	[wait showWindow:self];
	
	NSLog(@"RegionGrowing starts...");
	
	try
	{
		//distanceMapFilter->Update();
		#ifdef  UseApproximateSignedDistanceMapImageFilter
			approximateDistanceMapFilter->Update();	
		#else
			distanceMapFilter->Update();
		#endif
	}
	catch( itk::ExceptionObject & excep )
	{
		NSLog(@"RegionGrowing failed...");
		//return;
	}
	
	NSLog(@"Done...");
	
	/* 
	Get 6 and 4 neighbor maxima
	6 neighbor maxima is largest in 3 dimension
	4 neighbor maxima are largest in 2 dimensions
	Need to be larger than a minimum distance ? 10 - 20 pixels
	0.625  * 20 =  12.5 mm.
	*/
	
	NSLog(@"get max values");
	
	#ifdef  UseApproximateSignedDistanceMapImageFilter
		float *buff = approximateDistanceMapFilter->GetOutput()->GetBufferPointer();
	#else
		signed short *buff = distanceMapFilter->GetOutput()->GetBufferPointer();
	#endif
	[wait setString:@"Finding Distances"];

	NSMutableSet *pointSet = [NSMutableSet set];
	//[[NSData dataWithBytes:buff length:(width * height * depth * 2)] writeToFile:@"/Users/lpysher/Desktop/DistanceMap.data" atomically:YES];
	int i;
	for (z = minSize; z < d; z++) {
		
		long sliceAbove = sliceSize * (z - 1);
		long sliceBelow = sliceSize * (z + 1);
		long currentSlice = sliceSize * z;
		//NSLog(@"sliceAbove %d  sliceBelow %d", sliceAbove, sliceBelow);
		for (y = minSize; y < h; y++) {
			long rowAbove = width * (y - 1);
			long rowBelow = width * (y + 1);
			long currentRow = width * y;
			//NSLog(@"currentRow: %d", currentRow);
			for (x = minSize; x < w; x++) {
				long position = currentSlice + currentRow + x;
				
				#ifdef  UseApproximateSignedDistanceMapImageFilter
					// inside is negative
					float distance = buff[position];
				#else
					signed short distance = buff[position];
				#endif
				int isDistanceMaximum = 0;
				
				if (distance > minSize) {
					// get x pixels
					if (distance > buff[position - 1] && distance > buff[position + 1])
						isDistanceMaximum++;
					// get y pixels
					if (distance > buff[currentSlice + rowAbove + x] && distance > buff[currentSlice + rowBelow + x])
						isDistanceMaximum++;
					// get z pixels
					if (distance > buff[sliceAbove + currentRow + x] && distance > buff[sliceBelow + currentRow + x])
						isDistanceMaximum++;
					
					// if is Distance Maximum in neighborhood
					if (isDistanceMaximum > 1) {
						// add to set
						//NSLog(@"add point");
						#ifdef  UseApproximateSignedDistanceMapImageFilter
							[pointSet addObject:[OSIPoint3D pointWithX:(float)x  y:(float)y  z:(float)z value:[NSNumber numberWithFloat:distance]]];
						#else
							[pointSet addObject:[OSIPoint3D pointWithX:(float)x  y:(float)y  z:(float)z value:[NSNumber numberWithShort:distance]]];
						#endif	
						//change maxDistance
						if (distance > maxDistance) {
							maxDistance = distance;
							//NSLog(@"maxDistance = %f", maxDistance);
						}
						
					}
				}
			}
		}
	}
	
	[wait setString:@"Finding Centerline Points"];
	/*
	 Create subset of points 
	 iterate through pointSet looking for points with largest distances;
	 Decrease maxDistance unit we had enough points 
	*/
	NSMutableSet *nodeSet = [NSMutableSet set];
	int maxCount = 50;
	int count = 0;
	float scalingFactor = 1.0;
	//NSLog(@"Distance Point Count: %d", [pointSet count]);
	while (count < maxCount && maxDistance > minSize) {
		//NSLog(@"max distance: %f", maxDistance);
		NSEnumerator *enumerator = [pointSet objectEnumerator];
		OSIPoint3D *point;
		NSMutableSet *deleteSet = [NSMutableSet set];
		#ifdef  UseApproximateSignedDistanceMapImageFilter
			float distance;
		#else
			signed short distance;
		#endif
		//
		while (point = [enumerator nextObject]){
			//NSLog(@"current Point: %@", point);
			float positionSlice = [point z];
			float positionRow = [point y];
			float positionIndex = [point x];
			#ifdef  UseApproximateSignedDistanceMapImageFilter
				distance = [[point value] floatValue];
			#else
			distance = [[point value] shortValue];
			#endif
			
			if (distance >= maxDistance) {
				// Add node if is not within the range of previous nodes
				NSEnumerator *nodeEnumerator = [nodeSet objectEnumerator];
				OSIPoint3D *node;
				BOOL isNewNode = YES;
		
				while (node = [nodeEnumerator nextObject]) {
					// calculated distance 
					//long nodePosition = [node longValue];
					float nodeSlice = [node z];
					float nodeRow = [node y];
					float  nodeIndex = [node x];
					#ifdef  UseApproximateSignedDistanceMapImageFilter
						float nodeDistance = [[node value] floatValue];
					#else
						float nodeDistance = [[node value] shortValue];
					#endif
					float internodeDistance = sqrt(pow(positionSlice - nodeSlice, 2) + pow(positionRow - nodeRow, 2) + pow(positionIndex - nodeIndex, 2));
					//keep node away from other nodes
					if (internodeDistance < nodeDistance * scalingFactor) {
						// keep larger node.
						if (nodeDistance < distance)
							[nodeSet removeObject:node];
						else
							isNewNode = NO;
						break;
					}
					//else 
					
				}
				if (isNewNode) {
					NSLog(@"add Node: %f %f %f", positionIndex, positionRow, positionSlice);
					[nodeSet addObject: point];
					NSMutableArray  *roiImageList;
					NSArray *roiSeriesList = [srcViewer roiList];
					DCMPix	*curPix = [[srcViewer pixList] objectAtIndex: positionSlice * 2];
					ROI		*newROI;
					newROI = [[[ROI alloc] initWithType: t2DPoint :[curPix pixelSpacingX] :[curPix pixelSpacingY] :NSMakePoint( positionIndex * 2, positionRow * 2)] autorelease];
					[newROI setName: @"Centerline"];
					roiImageList = [roiSeriesList objectAtIndex: positionSlice * 2];
					[roiImageList addObject: newROI];	
					[newROI mouseRoiDown:NSMakePoint((float)positionIndex * 2,(float)positionRow * 2) :positionSlice * 2 :1.0];
				}
				
				[deleteSet addObject:point];
				
			}
			// get rid of points we have already evaluated
			[pointSet minusSet:deleteSet];
		}
		count = [nodeSet count];
		maxDistance -= 2;
			
	}
		[wait setString:@"Connecting Centerline"];
	
	/* 
	Connect nodes
	Criteria:
		1. Closest node;
		2. No distance less than minDistance interevening. Keep in lumen
	*/
	
	[wait close];
	[wait release];
	
	[srcViewer needsDisplayUpdate];
}


@end

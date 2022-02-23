/* ===========================================================================

    Copyright (c) The ART Development Team
    --------------------------------------

    For a comprehensive list of the members of the development team, and a
    description of their respective contributions, see the file
    "ART_DeveloperList.txt" that is distributed with the libraries.

    This file is part of the Advanced Rendering Toolkit (ART) libraries.

    ART is free software: you can redistribute it and/or modify it under the
    terms of the GNU General Public License as published by the Free Software
    Foundation, either version 3 of the License, or (at your option) any
    later version.

    ART is distributed in the hope that it will be useful, but WITHOUT ANY
    WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
    for more details.

    You should have received a copy of the GNU General Public License
    along with ART.  If not, see <http://www.gnu.org/licenses/>.

=========================================================================== */

#define ART_MODULE_NAME     ArnCube

#import "ArnCube.h"

static Pnt3D hullPointTable[8];
static Pnt3D centroidPoint;

Vec3D ARNCUBE_OBJECTSPACE_NORMAL_TABLE[6];

typedef struct ArnCube_GV
{
    ArnCube  * bounded_singleton;
    ArnCube  * bounded_surface_singleton;

    ArnCubeQuadrangularMapping  * mapping_singleton;
}
ArnCube_GV;


ART_MODULE_INITIALISATION_FUNCTION_EXEC_ONLY_ONCE
(
    //   code that gets executed only once

    hullPointTable[0] = PNT3D( 0.0, 0.0, 0.0 );
    hullPointTable[1] = PNT3D( 1.0, 0.0, 0.0 );
    hullPointTable[2] = PNT3D( 0.0, 0.0, 1.0 );
    hullPointTable[3] = PNT3D( 1.0, 0.0, 1.0 );
    hullPointTable[4] = PNT3D( 0.0, 1.0, 0.0 );
    hullPointTable[5] = PNT3D( 1.0, 1.0, 0.0 );
    hullPointTable[6] = PNT3D( 0.0, 1.0, 1.0 );
    hullPointTable[7] = PNT3D( 1.0, 1.0, 1.0 );

    centroidPoint = PNT3D( 0.5, 0.5, 0.5 );

    ARNCUBE_OBJECTSPACE_NORMAL_TABLE[0] = VEC3D( -1.0,  0.0,  0.0 );
    ARNCUBE_OBJECTSPACE_NORMAL_TABLE[1] = VEC3D(  1.0,  0.0,  0.0 );
    ARNCUBE_OBJECTSPACE_NORMAL_TABLE[2] = VEC3D(  0.0, -1.0,  0.0 );
    ARNCUBE_OBJECTSPACE_NORMAL_TABLE[3] = VEC3D(  0.0,  1.0,  0.0 );
    ARNCUBE_OBJECTSPACE_NORMAL_TABLE[4] = VEC3D(  0.0,  0.0, -1.0 );
    ARNCUBE_OBJECTSPACE_NORMAL_TABLE[5] = VEC3D(  0.0,  0.0,  1.0 );
,
    //   code that gets executed during every library start-up

    [ ArnCube registerWithRuntime ];
    [ ArnCubeQuadrangularMapping registerWithRuntime ];

    ArnCube_GV  * arncube_gv;

    arncube_gv = ALLOC(ArnCube_GV);

    ARNODE_SINGLETON(
        arncube_gv->bounded_singleton,
        ARNCUBE_BOUNDED_SINGLETON,
        [ ALLOC_INIT_OBJECT(ArnCube)
            : arshape_bounded | arshape_faces_planar
            ]
        );

    ARNODE_SINGLETON(
        arncube_gv->bounded_surface_singleton,
        ARNCUBE_BOUNDED_SURFACE_SINGLETON,
        [ ALLOC_INIT_OBJECT(ArnCube)
            :   arshape_bounded | arshape_singular | arshape_faces_planar
            ]
        );

    ARNODE_SINGLETON(
        arncube_gv->mapping_singleton,
        ARNCUBE_MAPPING_SINGLETON,
        [ ALLOC_INIT_OBJECT(ArnCubeQuadrangularMapping)
            ]
        );

    art_gv->arncube_gv = arncube_gv;
)

ART_MODULE_SHUTDOWN_FUNCTION_EXEC_ONLY_ONCE
(
    //   module has no code that gets executed only at the final module shutdown
,
    //   code that gets executed during all module shutdowns

    RELEASE_OBJECT( art_gv->arncube_gv->bounded_singleton );
    RELEASE_OBJECT( art_gv->arncube_gv->bounded_surface_singleton );
    RELEASE_OBJECT( art_gv->arncube_gv->mapping_singleton );

    FREE( art_gv->arncube_gv );
)


ArnCube  * arncube_bounded_singleton(
        ART_GV  * art_gv
        )
{
    return
        art_gv->arncube_gv->bounded_singleton;
}

ArnCube  * arncube_bounded_surface_singleton(
        ART_GV  * art_gv
        )
{
    return
        art_gv->arncube_gv->bounded_surface_singleton;
}

@implementation ArnCube

ARPCONCRETECLASS_DEFAULT_IMPLEMENTATION(ArnCube)
ARPSHAPE_DEFAULT_IMPLEMENTATION(
        !(shapeGeometry & arshape_singular),
        shapeGeometry & arshape_singular,
        6)

- (const Pnt3D *) getLocalHullPointTable
        : (int *) outHullSize
{
    *outHullSize = 8;
    return hullPointTable;
}

- (void) getLocalCentroid
        : (const ArTraversalState *) traversalState
        : (Pnt3D *) outCentroid
{
    *outCentroid = centroidPoint;
}

- (void) getLocalExtremalCoordinates
        : (const Vec3D *) inDirection
        : (Crd4 *) minCrd
        : (Crd4 *) maxCrd
{
    Vec3D extremalVector =
    VEC3D(
        0.5 * M_SIGN(XC(*inDirection)),
        0.5 * M_SIGN(YC(*inDirection)),
        0.5 * M_SIGN(ZC(*inDirection))
    );

    if (minCrd)
    {
        Pnt3D  point;

        pnt3d_vp_sub_p(
            & extremalVector,
            & centroidPoint,
            & point
            );

        c4_p3_to_c(
            & point,
              minCrd
            );
    }
    if (maxCrd)
    {
        Pnt3D  point;

        pnt3d_vp_add_p(
            & extremalVector,
            & centroidPoint,
            & point
            );

        c4_p3_to_c(
            & point,
              maxCrd
            );
    }
}

- (void) calculateNormalForLocalPnt3DE
        : (const ArTraversalState *) traversalState
        : (Pnt3DE *) point
{
    point->normal = ARNCUBE_OBJECTSPACE_NORMAL_TABLE[ point->faceIndex ];
}

- (ArNode <ArpMapping> *) createMappingFor
        : (ArMappingCriteria) criteria
{
    return
        art_gv->arncube_gv->mapping_singleton;
}

@end

//   This #import #defines the IN_3D_..., OUT_3D_..., etc. macros used
//   as shortcuts / code beatification by the mapping code below.

#import "ArSurfacePointMappingMacros.h"

@implementation ArnCubeQuadrangularMapping

ARPCONCRETECLASS_DEFAULT_IMPLEMENTATION(ArnCubeQuadrangularMapping)

ARPMAPPING_DEFAULT_IMPLEMENTATION(6)
ARPMAPPING_PATCH_PARAMETERISATION(ArcRectangularParameterisation)
ARPMAPPING_ONE_TO_ONE_PATCHING
ARPMAPPING_NO_ADJACENT_PATCHES

- (BOOL) getPnt2DE_for_ObjectSpacePnt3DE
        : (const ArTraversalState *) traversalState
        : (const Pnt3DE *) inPoint3D
        : (Pnt2DE *) outPoint2D
{
    OUT_2D_PATCHINDEX = IN_3D_FACEINDEX;

    switch ( IN_3D_FACEINDEX )
    {
        case 0:   // left face
        {
            OUT_2D_U = 1.0 - IN_3D_YC;
            OUT_2D_V =       IN_3D_ZC;
            break;
        }
        case 1:   // right face
        {
            OUT_2D_U =       IN_3D_YC;
            OUT_2D_V =       IN_3D_ZC;
            break;
        }
        case 2:   // front face
        {
            OUT_2D_U =       IN_3D_XC;
            OUT_2D_V =       IN_3D_ZC;
            break;
        }
        case 3:   // rear face
        {
            OUT_2D_U = 1.0 - IN_3D_XC;
            OUT_2D_V =       IN_3D_ZC;
            break;
        }
        case 4:   // bottom face
        {
            OUT_2D_U = 1.0 - IN_3D_XC;
            OUT_2D_V =       IN_3D_ZC;
            break;
        }
        case 5:   // top face
        {
            OUT_2D_U =       IN_3D_XC;
            OUT_2D_V =       IN_3D_YC;
            break;
        }
    }

    return YES;
}

- (BOOL) getObjectSpacePnt3DE_for_Pnt2DE
        : (const ArTraversalState *) traversalState
        : (const Pnt2DE *) inPoint2D
        : (Pnt3DE *) outPoint3D
{
    OUT_3D_FACEINDEX = IN_2D_PATCHINDEX;

    switch ( IN_2D_PATCHINDEX )
    {
        case 0:   // left face
        {
            OUT_3D_XC =  0.0;
            OUT_3D_YC =  1.0 - IN_2D_U;
            OUT_3D_ZC =  IN_2D_V;
            OUT_3D_XN = -1.0;
            OUT_3D_YN =  0.0;
            OUT_3D_ZN =  0.0;
            break;
        }
        case 1:   // right face
        {
            OUT_3D_XC =  1.0;
            OUT_3D_YC =  IN_2D_U;
            OUT_3D_ZC =  IN_2D_V;
            OUT_3D_XN =  1.0;
            OUT_3D_YN =  0.0;
            OUT_3D_ZN =  0.0;
            break;
        }
        case 2:   // front face
        {
            OUT_3D_XC =  IN_2D_U;
            OUT_3D_YC =  0.0;
            OUT_3D_ZC =  IN_2D_V;
            OUT_3D_XN =  0.0;
            OUT_3D_YN = -1.0;
            OUT_3D_ZN =  0.0;
            break;
        }
        case 3:   // rear face
        {
            OUT_3D_XC =  1.0 - IN_2D_U;
            OUT_3D_YC =  1.0;
            OUT_3D_ZC =  IN_2D_V;
            OUT_3D_XN =  0.0;
            OUT_3D_YN =  1.0;
            OUT_3D_ZN =  0.0;
            break;
        }
        case 4:   // bottom face
        {
            OUT_3D_XC =  1.0 - IN_2D_U;
            OUT_3D_YC =  IN_2D_V;
            OUT_3D_ZC =  0.0;
            OUT_3D_XN =  0.0;
            OUT_3D_YN =  0.0;
            OUT_3D_ZN = -1.0;
            break;
        }
        case 5:   // top face
        {
            OUT_3D_XC =  IN_2D_U;
            OUT_3D_YC =  IN_2D_V;
            OUT_3D_ZC =  1.0;
            OUT_3D_XN =  0.0;
            OUT_3D_YN =  0.0;
            OUT_3D_ZN =  1.0;
            break;
        }
    }

    return YES;
}

@end

// ===========================================================================

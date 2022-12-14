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

#include "ART_Foundation.h"

ART_MODULE_INTERFACE(ArDifferentialGeometry)

@protocol ArpNode;
@class ArnCompoundFace;

/* ---------------------------------------------------------------------------
    'ArFaceOnShapeType'
        This encodes shape face information that is relevant for shape
        faces that have been generated by a raycaster.  The 'backside'
        property is with respect to the ray and the local normal of
        the primitive that the shape face belongs to.  The 'negative'
        information concerns faces of CSG objects.
--------------------------------------------------------------------------- */
typedef enum ArFaceOnShapeType
{
    arface_on_shape_default                 = 0x00,
    arface_on_shape_is_singular             = 0x01,
    arface_on_shape_is_planar               = 0x02,
    arface_on_shape_reverse                 = 0x04,
    arface_on_shape_has_been_CSG_subtracted = 0x08
}
ArFaceOnShapeType;

//   the logical opposite to "reverse" is obverse, but an enum should only
//   contain one entry per value, so this goes here as #define

#define arface_on_shape_obverse     arface_on_shape_default

/* ---------------------------------------------------------------------------
    'ArFaceOnShape'
        A structure defining one face of a shape.  Optionally this face is
        joined to other faces by referencing a face object of type
        'ArnCompoundFace'.
--------------------------------------------------------------------------- */

@protocol ArpShape;
@class    ArNode;

typedef struct ArFaceOnShape
{
    ArNode <ArpShape>  * shape;
    long                 sheet;
    long                 face;
    ArFaceOnShapeType    type;
    ArnCompoundFace    * compound_face;
}
ArFaceOnShape;

/* ---------------------------------------------------------------------------
    'ARSHAPEFACE...'
        Various macros to access and operate on an 'ArFaceOnShape'.
--------------------------------------------------------------------------- */
#define ARFACE_ON_SHAPE(_s,_i,_t,_f)        ((ArFaceOnShape){(_s),(_i),(_t),(_f), NULL})
#define ARFACE_ON_SHAPE_NONE                ARFACE_ON_SHAPE(0,-1,0,0)
#define ARFACE_ON_SHAPE_INVALID_INDEX       (-1)
#define ARFACE_ON_SHAPE_SHAPE(__sf)         (__sf).shape
#define ARFACE_ON_SHAPE_TYPE(__sf)          (__sf).type
#define ARFACE_ON_SHAPE_FACE(__sf)          (__sf).face
#define ARFACE_ON_SHAPE_COMPOUND_FACE(__sf) (__sf).compound_face
#define ARFACE_ON_SHAPE_SHEET(__sf)         (__sf).sheet
#define ARFACE_ON_SHAPE_FACEINDEX           ARFACE_ON_SHAPE_FACE

BOOL arface_on_shape_same_compound_face(
        const ArFaceOnShape * sf0, const ArFaceOnShape * sf1
        );

BOOL arface_on_shape_same_shape_and_face(
        const ArFaceOnShape * sf0, const ArFaceOnShape * sf1
        );

BOOL arface_on_shape_same(
        const ArFaceOnShape * sf0, const ArFaceOnShape * sf1
        );

void arface_on_shape_update_crc32(
        const ArFaceOnShape * sf,
        int interpolated,
        UInt32 * crc32
        );

/* ---------------------------------------------------------------------------
    'ArMaterialPair'
        A pair of materials defining a transition from one material into
        another.  This is used to specify the materials separated by a
        facet.
--------------------------------------------------------------------------- */

@protocol ArpVolumeMaterial;

typedef struct ArMaterialPair
{
    ArNode <ArpVolumeMaterial>  * from;
    ArNode <ArpVolumeMaterial>  * into;
}
ArMaterialPair;

#define ARMATERIALPAIR(_m0,_m1)         ((ArMaterialPair){ _m0, _m1 })
#define ARMATERIALPAIR_NONE             ARMATERIALPAIR(0,0)

#define ARMATERIALPAIR_FROM(__mp)     (__mp).from
#define ARMATERIALPAIR_INTO(__mp)     (__mp).into

BOOL armaterialpair_same(
        const ArMaterialPair * mp0, const ArMaterialPair * mp1
        );

BOOL armaterialpair_flipped(
        const ArMaterialPair * mp0, const ArMaterialPair * mp1
        );

BOOL armaterialpair_flipped_same(
        int flip, const ArMaterialPair * mp0, const ArMaterialPair * mp1
        );

void armaterialpair_invert(
        ArMaterialPair * mp
        );

void armaterialpair_update_crc32(
        const ArMaterialPair * mp, UInt32 * crc32
        );


/* ---------------------------------------------------------------------------

    'ArDifferentialGeometry' struct

        This data structure holds the information about object and
        material properties at a given surface point. While it does not
        represent a microfact in the traditional RenderMan sense, it still
        serves much the same purpose in the ray-based renderers insofar as it
        is used to represent the properties which are valid in a
        differentially small, stable area around a given hitpoint.

------------------------------------------------------------------------aw- */


typedef struct ArDifferentialGeometry
{
    ArMaterialPair      materialPair;
    ArFaceOnShape       faceOnShape;
    Vec3D               localNormal;
}
ArDifferentialGeometry;

#define ARDIFFERENTIALGEOMETRY(_mp,_sf) ((ArDifferentialGeometry){ (_mp), (_sf) })
#define ARDIFFERENTIALGEOMETRY_NONE \
            ARDIFFERENTIALGEOMETRY( ARMATERIALPAIR_NONE, ARFACE_ON_SHAPE_NONE )

#define ARDIFFERENTIALGEOMETRY_FACE_ON_SHAPE(__mf)     (__mf).faceOnShape
#define ARDIFFERENTIALGEOMETRY_SHAPE(__mf)         \
    ARFACE_ON_SHAPE_SHAPE(ARDIFFERENTIALGEOMETRY_FACE_ON_SHAPE(__mf))
#define ARDIFFERENTIALGEOMETRY_FACE_ON_SHAPE_TYPE(__mf)         \
    ARFACE_ON_SHAPE_TYPE(ARDIFFERENTIALGEOMETRY_FACE_ON_SHAPE(__mf))
#define ARDIFFERENTIALGEOMETRY_FACEINDEX(__mf)         \
    ARFACE_ON_SHAPE_FACEINDEX(ARDIFFERENTIALGEOMETRY_FACE_ON_SHAPE(__mf))

#define ARDIFFERENTIALGEOMETRY_MATERIALPAIR(__mf)  (__mf).materialPair

#define ARDIFFERENTIALGEOMETRY_MATERIAL_FROM(__mf) \
    ARMATERIALPAIR_FROM( ARDIFFERENTIALGEOMETRY_MATERIALPAIR(__mf) )
#define ARDIFFERENTIALGEOMETRY_MATERIAL_INTO(__mf) \
    ARMATERIALPAIR_INTO( ARDIFFERENTIALGEOMETRY_MATERIALPAIR(__mf) )

#define ARDIFFERENTIALGEOMETRY_LOCAL_NORMAL(__mf)               (__mf).localNormal

ArDifferentialGeometry ardifferentialgeometry_reflect(
        ArDifferentialGeometry  mf_0
        );

void ardifferentialgeometry_update_crc32(
        ArDifferentialGeometry  * mf_0,
        int             interpolated,
        UInt32        * crc32
        );

BOOL ardifferentialgeometry_same(
        const ArDifferentialGeometry * mf_0,
        const ArDifferentialGeometry * mf_1
        );

// ===========================================================================

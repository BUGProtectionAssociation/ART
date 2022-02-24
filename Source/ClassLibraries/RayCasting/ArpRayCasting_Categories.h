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

ART_MODULE_INTERFACE(ArpRayCasting_Categories)

#import "ART_Shape.h"
#import "ArnRayCaster.h"

/* ---------------------------------------------------------------------------

    #define ART_WITH_RAYCASTING_DEBUG_OUTPUT

    Uncomment this  #define to get step-by-step debug printfs during
    intersection list creation. Warning: this generates LOTS of output you
    never want to see during normal operation! The only scenario where this
    might be useful is when you are debugging the creation and manipulation
    of intersection lists.

    Note that the output generated by this option will be in the order in
    which the nodes in the scene graph are actually traversed, i.e. not in
    the order you might initially expect (this depends on how familiar you
    are with scene graph traversals, though). This is most obvious for
    internal nodes, such as CSG operators. For a CSG node, you will see
    the printouts from the entire subtree evaluations before the CSG node
    printout finishes!

    Hint: the only usage scenario where this generates comprehensible
          output is if you run a rendering job for a single pixel image,
          with one sample per pixel (i.e. if only a single recursive
          descent into the scene is made).

------------------------------------------------------------------------aw- */

//#define ART_WITH_RAYCASTING_DEBUG_OUTPUT

@interface AraBBox                  ( RayCasting ) < ArpRayCasting > @end
@interface AraVolumeMaterial              ( RayCasting ) < ArpRayCasting > @end
@interface AraRules                 ( RayCasting ) < ArpRayCasting > @end
@interface AraSurfaceMaterial               ( RayCasting ) < ArpRayCasting > @end
@interface AraTrafo3D               ( RayCasting ) < ArpRayCasting > @end
@interface AraVertices              ( RayCasting ) < ArpRayCasting > @end
@interface AraVariables             ( RayCasting ) < ArpRayCasting > @end
@interface AraWorld                 ( RayCasting ) < ArpRayCasting > @end
@interface AraCombinedAttributes    ( RayCasting ) < ArpRayCasting > @end
@interface AraCombinedReference     ( RayCasting ) < ArpRayCasting > @end

ART_MODULE_INTERFACE(AraBBoxRayCasting)
ART_MODULE_INTERFACE(AraMaterialRayCasting)
ART_MODULE_INTERFACE(AraRulesRayCasting)
ART_MODULE_INTERFACE(AraSurfaceRayCasting)
ART_MODULE_INTERFACE(AraTrafo3DRayCasting)
ART_MODULE_INTERFACE(AraVerticesRayCasting)
ART_MODULE_INTERFACE(AraVariablesRayCasting)
ART_MODULE_INTERFACE(AraWorldRayCasting)
ART_MODULE_INTERFACE(AraCombinedAttributesRayCasting)
ART_MODULE_INTERFACE(AraCombinedReferenceRayCasting)

@interface ArnCSGand            ( RayCasting ) < ArpRayCasting > @end
@interface ArnCSGor             ( RayCasting ) < ArpRayCasting > @end
@interface ArnCSGorBBox         ( RayCasting ) < ArpRayCasting > @end
@interface ArnCSGsub            ( RayCasting ) < ArpRayCasting > @end
@interface ArnCSGcombine        ( RayCasting ) < ArpRayCasting > @end
@interface ArnNamedNodeSet      ( RayCasting ) < ArpRayCasting > @end
@interface ArnSelectedNode      ( RayCasting ) < ArpRayCasting > @end
@interface ArnReference         ( RayCasting ) < ArpRayCasting > @end
@interface ArnRepeater          ( RayCasting ) < ArpRayCasting > @end
@interface ArnUnion             ( RayCasting ) < ArpRayCasting > @end
@interface ArnTriangleMesh   ( RayCasting ) < ArpRayCasting > @end

ART_MODULE_INTERFACE(ArnCSGRayCasting)
ART_MODULE_INTERFACE(ArnCSGBBoxRayCasting)
ART_MODULE_INTERFACE(ArnNamedNodeSetRayCasting)
ART_MODULE_INTERFACE(ArnSelectedNodeRayCasting)
ART_MODULE_INTERFACE(ArnReferenceRayCasting)
ART_MODULE_INTERFACE(ArnRepeaterRayCasting)
ART_MODULE_INTERFACE(ArnUnionRayCasting)
ART_MODULE_INTERFACE(ArnTriangleMeshRayCasting)

@interface ArnCone              ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnCube              ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnCylinder          ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnHyperboloid       ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnInfSphere         ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnParaboloid        ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnQuadrangle        ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnSphere            ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnTorus             ( RayCasting ) < ArpShapeRayCasting > @end
@interface ArnTriangle          ( RayCasting ) < ArpShapeRayCasting > @end

ART_MODULE_INTERFACE(ArnConeRayCasting)
ART_MODULE_INTERFACE(ArnCubeRayCasting)
ART_MODULE_INTERFACE(ArnCylinderRayCasting)
ART_MODULE_INTERFACE(ArnHyperboloidRayCasting)
ART_MODULE_INTERFACE(ArnInfSphereRayCasting)
ART_MODULE_INTERFACE(ArnParaboloidRayCasting)
ART_MODULE_INTERFACE(ArnQuadrangleRayCasting)
ART_MODULE_INTERFACE(ArnSphereRayCasting)
ART_MODULE_INTERFACE(ArnTorusRayCasting)
ART_MODULE_INTERFACE(ArnTriangleRayCasting)

// ===========================================================================

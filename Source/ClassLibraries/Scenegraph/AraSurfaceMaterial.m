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

#define ART_MODULE_NAME     AraSurfaceMaterial

#import "AraSurfaceMaterial.h"
#import "ArnVisitor.h"

ART_MODULE_INITIALISATION_FUNCTION
(
    (void) art_gv;
    [ AraSurfaceMaterial registerWithRuntime ];
)

ART_NO_MODULE_SHUTDOWN_FUNCTION_NECESSARY


@implementation AraSurfaceMaterial

ARPCONCRETECLASS_DEFAULT_IMPLEMENTATION(AraSurfaceMaterial)

- (id) init
        : (ArNodeRef) newNode
        : (ArNodeRef) newSurface
{
    ART_ERRORHANDLING_MANDATORY_ARPROTOCOL_CHECK(
        ARNODEREF_POINTER(newSurface),
        ArpSurfaceMaterial
        );

    self =
        [ super init
            :   newNode
            :   newSurface
            ];

    return self;
}

- (void) visit
        : (ArnVisitor *) visitor
{
    if ( [ visitor wantsToInteractWith: self ] )
    {
        if ( arnvisitor_push_attributes(visitor) )
        {
            ArNodeRef  nodeRefStore;

            [ visitor pushSurfaceMaterialRef
                :   WEAK_NODE_REFERENCE( SURFACE_MATERIAL_ATTRIBUTE )
                : & nodeRefStore ];

            [ super visit
                :   visitor ];

            [ visitor popSurfaceMaterial
                : & nodeRefStore ];
        }
        else
            [ super visit
                :   visitor ];
    }
}

- (ArNode *) modify
        : (ArnVisitor *) visitor
{
    if ( [ visitor wantsToInteractWith: self ] )
    {
        if ( arnvisitor_push_attributes(visitor) )
        {
            ArNodeRef  nodeRefStore;

            [ visitor pushSurfaceMaterialRef
                :   WEAK_NODE_REFERENCE( SURFACE_MATERIAL_ATTRIBUTE )
                : & nodeRefStore
                ];

            ArNode  * result =
                [ super modify
                    :   visitor
                    ];

            [ visitor popSurfaceMaterial
                : & nodeRefStore
                ];

            return result;
        }
        else
            return
                [ super modify
                    :   visitor
                    ];
    }
    else
        return self;
}

- (ArNode <ArpSurfaceMaterial> *) unambigousSubnodeSurfaceMaterial
{
    return SURFACE_MATERIAL_ATTRIBUTE;
}

@end

@implementation ArNode ( SurfaceMaterial )

- (AraSurfaceMaterial *) createSurfaceMaterialAttribute
        : (ArNode <ArpSurfaceMaterial> *) surfaceMaterialNode
{
    id  result =
        [ ALLOC_INIT_OBJECT(AraSurfaceMaterial)
            :   HARD_NODE_REFERENCE(self)
            :   HARD_NODE_REFERENCE(surfaceMaterialNode)
            ];

    return result;
}

@end

// ===========================================================================

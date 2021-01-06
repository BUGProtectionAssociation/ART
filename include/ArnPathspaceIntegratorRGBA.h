/* ===========================================================================

    Copyright (c) 1996-2020 The ART Development Team
    ------------------------------------------------

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

ART_MODULE_INTERFACE(ArnPathspaceIntegratorRGBA)

#import "ART_MiscellaneousStructs.h"
#import "ART_MiscellaneousClasses.h"
#import "ART_Scenegraph.h"

@interface ArnPathspaceIntegratorRGBA
        : ArnUnary
        < ArpConcreteClass, ArpCoding, ArpPathspaceIntegratorCore >
{
    //   Pointers to external entities

    ArcPhaseInterfaceCache             * phaseInterfaceCache;
    ArcObject <ArpRandomGenerator>     * randomGenerator;
    ArNode <ArpWorld, ArpRayCasting>   * entireScene;
    ArcFreelist                        * intersectionFreelist;

    //   Auxiliary data structures used during ray traversals

    ArcSurfacePoint                   * eyePoint;
    unsigned int                        numberOfSamplesPerPixel;
    ArRayTree                           rayTree;
}

- init
        : (ArNode <ArpRayCaster> *) newRayCaster
        ;

@end

// ===========================================================================

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

#import "ART_Foundation.h"

ART_MODULE_INTERFACE(ArnRayleighVolumeMaterial)

#import "ART_Scenegraph.h"

#import "ArnNoClosedFormVolumeMaterial.h"
#import "ArnRayleighPhaseFunction.h"

/* ===========================================================================
    
    Homogeneous material similar to ArnHNSVolumeMaterial that exhibits
    isotropic scattering. The absorption coefficient is taken from exctinction
    of the complex IOR, scattering coefficient is specified separately. These
    two are then added to produce the total cross section.
    Closed form evaluation is not available and not shortcuts for clear
    and opaque volumes are present.
 
=========================================================================== */


@interface ArnRayleighVolumeMaterial
        : ArnNoClosedFormVolumeMaterial
{
}

- init
        : (ArNode <ArpSpectrum> *) newIOR
        : (ArNode <ArpSpectrum> *) newExtinction
        : (double                ) newParticlesPerM3
        : (double                ) newVolumePolarisability
        : (double                ) newDepolarisationFactor
        ;

@end


// ===========================================================================

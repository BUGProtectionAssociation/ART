/* ===========================================================================

    Copyright (c) 1996-2019 The ART Development Team
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

#define ART_MODULE_NAME     ArfPLY

#import "ArfPLY.h"

#import "ArnTriangleMesh.h"


#import "ArnEmbreeUtils.h" // TODO: remove later

static const char * arfply_magic_string =
                    "ply";
static const char * arfply_short_class_name =
                    "PLY";
static const char * arfply_long_class_name =
                    "PLY mesh";
const char * arfply_exts[] =
                    { "ply", 0 };

ART_MODULE_INITIALISATION_FUNCTION
(
    [ ArfPLY registerWithFileProbe
        :   art_gv
        ];
)

ART_NO_MODULE_SHUTDOWN_FUNCTION_NECESSARY


@implementation ArfPLY

ARPFILE_DEFAULT_IMPLEMENTATION( ArfPLY, arfiletypecapabilites_read )
ARPPARSER_AUXLIARY_NODE_DEFAULT_IMPLEMENTATION

+ (const char **) extensions
{
    return arfply_exts;
}

+ (const char*) magicString
{
    return arfply_magic_string;
}

- (const char*) shortClassName
{
    return arfply_short_class_name;
}

- (const char*) longClassName
{
    return arfply_long_class_name;
}

+ (ArFiletypeMatch) matchWithStream
    : (ArcObject <ArpStream> *) stream
{
    char  buffer[5];

    [ stream read
        :   buffer
        :   1
        :   4
        ];

    buffer[4] = 0;

    if ( strstr(buffer, [self magicString]) != 0 )
        return arfiletypematch_exact;
    else
        return arfiletypematch_impossible;
}

- initWithFile: (ArcFile *) newFile
{
    file = newFile;
    return self;
}

- (void) dealloc
{
    [ super dealloc ];
}

- (void) parseFile
        : (ArNode **) objectPtr
{
    [ self parseFileGetExternals
        :   objectPtr
        :   0
        ];
}

- (void) parseFileGetExternals
        : (ArNode **) objectPtr
        : (ArList *) externals
{
    ArNode  * newMesh;
    const char * filename = [ file name ];

    // [Sebastian] TODO replace the condition with a macro later
    if(art_gv->embree_enabed) {
        ArnEmbreeUtils * embreeUtils = [[ArnEmbreeUtils alloc] init];
        newMesh = [embreeUtils embreegeometry_from_ply: art_gv path: filename];
    }
    else
        newMesh = arntrianglemesh_from_ply(art_gv, arshape_solid, filename );

    if ( newMesh == NULL )
            ART_ERRORHANDLING_FATAL_ERROR(
            "error when reading PLY mesh '%s'"
            ,   [ file name ]
            );

    *objectPtr = newMesh;
}

- (void) parseStream
        : (ArNode **) objectPtr
        : (ArcObject <ArpStream> *) stream
{
    ART__CODE_IS_WORK_IN_PROGRESS__EXIT_WITH_ERROR
}

@end

// ===========================================================================

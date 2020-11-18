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

#define ART_MODULE_NAME     ArfOpenEXR

//  The extern "C" wrapper, and the foundation include *before* the main
//  header include serve the purpose of including the normal ART Foundation
//  headers as designated C, before the ArfOpenEXR header is parsed.

#include "ART_Foundation.h"


#import "ART_ImageData.h"
#import "ART_ColourAndSpectra.h"
#import "ArfOpenEXR.h"
#import "ArfOpenEXRWrapper.h"

#import "ApplicationSupport.h"


#ifdef ART_WITH_OPENEXR

#import "ArfRasterImageImplementationMacros.h"

static const char * arfexr_short_class_name = "EXR";
static const char * arfexr_long_class_name  = "OpenEXR";
static const char * arfexr_extension[] =
{
    "exr", "EXR",
    0
};

#define G8_DATA         ((Grey8 *)dataLine)
#define C32_DATA        ((Colour32 *)dataLine)

#define G8_DATA_NC      dataLine
#define C32_DATA_NC     dataLine

@class ArfOpenEXR;

@implementation ArfOpenEXR

ARPFILE_DEFAULT_IMPLEMENTATION(
    ArfOpenEXR,
    arfiletypecapabilites_read |
    arfiletypecapabilites_write
    )

ARFRASTERIMAGE_DEFAULT_IMPLEMENTATION(LightAlpha,exr)


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
    *objectPtr =
        [ ALLOC_INIT_OBJECT(ArnFileImage)
            :   [ file name ]
            ];
}


/* ----------------------------------------------------------------------

    Opening an OpenEXR for *reading*
    
    This returns an ImageInfo for the new image

---------------------------------------------------------------------- */

- (ArnImageInfo *) open
{
    _spectralChannels = 0;

    _isSpectral = NO;
    _containsPolarisationData = NO;
    
    _bufferRGBA = NULL;

    _bufferS0 = NULL;
    _bufferS1 = NULL;
    _bufferS2 = NULL;
    _bufferS3 = NULL;

    float** spectral_buffers[4] = { &_bufferS0, &_bufferS1, &_bufferS2, &_bufferS3};
    double* wavelengths_nm = NULL;

    /* ------------------------------------------------------------------
        Read info from the EXR file.
    ------------------------------------------------------------------ */
    int width, height;
    int isPolarised;
    
    readEXR(
         [ self->file name ],
        & width, 
        & height,
        & _bufferRGBA,
        spectral_buffers,
        & wavelengths_nm,
        & _spectralChannels,
        & isPolarised
    );

    if (isPolarised) {
        _containsPolarisationData = YES;
    } else {
        _containsPolarisationData = NO;
    }

    XC(_size) = width;
    YC(_size) = height;
    FVec2D  resolution = FVEC2D(72.0, 72.0);

    // TODO: use this information to check constistency with internal
    // ART wavelengths.
    FREE_ARRAY(wavelengths_nm);

    /* ------------------------------------------------------------------
        Set the datatype according to the number of channels.
    ------------------------------------------------------------------ */

    switch ( _spectralChannels )
    {
        case 0:   _dataType = ardt_rgba; break;
        case 8:   _dataType = ardt_spectrum8; break;
        case 11:  _dataType = ardt_spectrum11; break;
        case 18:  _dataType = ardt_spectrum18; break;
        case 46:  _dataType = ardt_spectrum46; break;
        // default:  ART_ERRORHANDLING_FATAL_ERROR;
    }

    /* ------------------------------------------------------------------
        Polarisation information is only used if the image is loaded by
            a polarisation-aware executable, otherwise it is ignored.
    ------------------------------------------------------------------ */

    if (    LIGHT_SUBSYSTEM_IS_IN_POLARISATION_MODE
         && _containsPolarisationData )
    {
        _dataType = _dataType | ardt_polarisable;
        ARREFFRAME_RF_I( _referenceFrame, 0 ) = VEC3D( 1.0, 0.0, 0.0 );
        ARREFFRAME_RF_I( _referenceFrame, 1 ) = VEC3D( 0.0, 1.0, 0.0 );
    }

   
    /* ------------------------------------------------------------------
            Create ImageInfo instance for the image, and allocate memory
            for scanlines and individual pixels.
       ------------------------------------------------------------------ */

    _imageInfo =
        [ ALLOC_INIT_OBJECT(ArnImageInfo)
            :   _size
            :   _dataType
            :   _dataType
            :   resolution
            ];

    // This is allocated by the readEXR function
    // if (_spectralChannels > 0) {
    //     _bufferS0 = ALLOC_ARRAY(float, XC(_size) * YC(_size) * _spectralChannels);
        
    //     if (    LIGHT_SUBSYSTEM_IS_IN_POLARISATION_MODE
    //         && _containsPolarisationData ) {
    //         _bufferS1 = ALLOC_ARRAY(float, XC(_size) * YC(_size) * _spectralChannels);
    //         _bufferS2 = ALLOC_ARRAY(float, XC(_size) * YC(_size) * _spectralChannels);
    //         _bufferS3 = ALLOC_ARRAY(float, XC(_size) * YC(_size) * _spectralChannels);
    //     }
    // }

    // _bufferRGBA = ALLOC_ARRAY(float, XC(_size) * YC(_size) * 4);

    _scanline = ALLOC_ARRAY( ArLightAlpha *, XC(_size) );

    for ( unsigned int i = 0; i < XC(_size); i++ ) {
        _scanline[i] =
            arlightalpha_d_alloc_init_unpolarised(
                art_gv,
                0.0
                );
    }
    
    return _imageInfo;
}

- (void) _convertPixelToCol
        : (float *)          vals
        : (ArSpectrum *)     outBuf
{
    switch (_spectralChannels)
    {
        case 8:
        {
            ArSpectrum8 inSpec;
            for (int i = 0; i < 8; i++)
                inSpec.c.x[i] = vals[i];
                
            s8_to_spc(
                  art_gv,
                & inSpec,
                  outBuf
                ) ;
            break;
        }
        case 11:
        {
            ArSpectrum11 inSpec;
            for (int i = 0; i < 11; i++)
                inSpec.c.x[i] = vals[i];
                
            s11_to_spc(
                  art_gv,
                & inSpec,
                  outBuf
                ) ;
            break;
        }
        case 18:
        {
            ArSpectrum18 inSpec;
            for (int i = 0; i < 18; i++)
                inSpec.c.x[i] = vals[i];
                
            s18_to_spc(
                  art_gv,
                & inSpec,
                  outBuf
                ) ;
            break;
        }
        case 46:
        {
            ArSpectrum46 inSpec;
            for (int i = 0; i < 46; i++)
                inSpec.c.x[i] = vals[i];
                
            s46_to_spc(
                  art_gv,
                & inSpec,
                  outBuf
                ) ;
            break;
        }
    }
}

- (void) getPlainImage
        : (IPnt2D) start
        : (ArnPlainImage *) image
{
    ArSpectrum *colBufS0 = spc_d_alloc_init( art_gv, 0.0 );
    ArSpectrum *colBufS1 = spc_d_alloc_init( art_gv, 0.0 );
    ArSpectrum *colBufS2 = spc_d_alloc_init( art_gv, 0.0 );
    ArSpectrum *colBufS3 = spc_d_alloc_init( art_gv, 0.0 );
        

    for ( long y = 0; y < YC(image->size); y++ ) {
        for ( long x = 0; x < XC(image->size); x++ ) {
            if (_spectralChannels > 0) {
                [ self _convertPixelToCol
                    :   &_bufferS0[_spectralChannels * (y * XC(image->size) + x)]
                    :   colBufS0
                    ];
                
                if ( LIGHT_SUBSYSTEM_IS_IN_POLARISATION_MODE && _containsPolarisationData ) {
                    [ self _convertPixelToCol
                        :   &_bufferS1[_spectralChannels * (y * XC(image->size) + x)]
                        :   colBufS1
                        ];
                    
                    [ self _convertPixelToCol
                        :   &_bufferS2[_spectralChannels * (y * XC(image->size) + x)]
                        :   colBufS2
                        ];
                    
                    [ self _convertPixelToCol
                        :   &_bufferS3[_spectralChannels * (y * XC(image->size) + x)]
                        :   colBufS3
                        ];
                    
                    ArStokesVector  sv =
                    {
                        {
                        colBufS0,
                        colBufS1,
                        colBufS2,
                        colBufS3
                        }
                    };

                    arlight_s_rf_init_polarised_l(
                        art_gv,
                        & sv,
                        & _referenceFrame,
                        ARLIGHTALPHA_LIGHT( *_scanline[x] )
                        );
                    
                } else {
                    arlight_s_init_unpolarised_l(
                        art_gv,
                        colBufS0,
                        ARLIGHTALPHA_LIGHT( *_scanline[x] )
                        );
                }
            } else {
                ArRGB  rgb = ARRGB(
                    _bufferRGBA[4 * (y * XC(image->size) + x) + 0],
                    _bufferRGBA[4 * (y * XC(image->size) + x) + 1],
                    _bufferRGBA[4 * (y * XC(image->size) + x) + 2]
                );

                rgb_to_spc(
                    art_gv,
                    & rgb,
                    colBufS0
                    ) ;

                arlight_s_init_unpolarised_l(
                        art_gv,
                        colBufS0,
                        ARLIGHTALPHA_LIGHT( *_scanline[x] )
                        );
            }
            
            ARLIGHTALPHA_ALPHA( *_scanline[x] ) = 1.0;
        }
        
        
        /* ------------------------------------------------------------------
             Final step: the ArLight scanline is inserted into the
             image. The cast is justified since only ArnArLightImages get
             to interoperate with ArfARTRAW.
        ------------------------------------------------------------------ */

        [ ((ArnLightAlphaImage*)image) setLightAlphaRegion
            :   IPNT2D(0, y)
            :   IVEC2D(XC(image->size), 1)
            :   _scanline
            :   0
            ];
    }
    
    spc_free(art_gv, colBufS0);
    spc_free(art_gv, colBufS1);
    spc_free(art_gv, colBufS2);
    spc_free(art_gv, colBufS3);
}

/* ----------------------------------------------------------------------

    Opening an OpenEXR for *writing*
    
    The provided ImageInfo is used to set the file specifics

---------------------------------------------------------------------- */

- (void) open
        : (ArnImageInfo *) imageInfo
{
    _imageInfo = [imageInfo retain];

    _size = [ _imageInfo size ];
    _dataType = [ imageInfo dataType ];

    const int width = XC(_size);
    const int height = YC(_size);

    _bufferRGBA = NULL;

    _bufferS0 = NULL;
    _bufferS1 = NULL;
    _bufferS2 = NULL;
    _bufferS3 = NULL;
    
    // Memory allocation

    if (   _dataType == ardt_rgb
        || _dataType == ardt_rgba
        || _dataType == ardt_xyz
        || _dataType == ardt_xyza) {
        _dataType = ardt_rgba;
        _isSpectral = NO;
        _containsPolarisationData = NO;
        _bufferRGBA = ALLOC_ARRAY(float, 4 * width * height);

        // ArColourSpace  const * cs = DEFAULT_RGB_SPACE_REF;
        
        // //   Rec. 709 a.k.a. sRGB is assumed in OpenEXRs if the
        // //   primaries are not specified in the header
        
        // if ( DEFAULT_RGB_SPACE_REF != ARCSR_sRGB )
        // {
        //     Imf::Chromaticities exrChr = Imf::Chromaticities
        //         (Imath::V2f (XC(ARCSR_R(cs)), YC(ARCSR_R(cs))),
        //          Imath::V2f (XC(ARCSR_G(cs)), YC(ARCSR_G(cs))),
        //          Imath::V2f (XC(ARCSR_B(cs)), YC(ARCSR_B(cs))),
        //          Imath::V2f (XC(ARCSR_W(cs)), YC(ARCSR_W(cs))));

        //     addChromaticities (exrHeader, exrChr);
        //     addAdoptedNeutral (exrHeader, exrChr.white);
        // }

    } else {
        _isSpectral = YES;
        _containsPolarisationData = (LIGHT_SUBSYSTEM_IS_IN_POLARISATION_MODE) ? YES : NO;
        
        switch (_dataType) {
            case ardt_spectrum8:
            case ardt_spectrum8_polarisable:  _spectralChannels = 8; break;
            case ardt_spectrum11:
            case ardt_spectrum11_polarisable: _spectralChannels = 11; break;
            case ardt_spectrum18:
            case ardt_spectrum18_polarisable: _spectralChannels = 18;  break;
            case ardt_spectrum46:
            case ardt_spectrum46_polarisable: _spectralChannels = 46;  break;
            default:
                ART_ERRORHANDLING_FATAL_ERROR(
                      "unsupported EXR colour type %d requested",
                      _dataType
                );
        }

        _bufferS0 = ALLOC_ARRAY(float, width * height * _spectralChannels);
        
        if (LIGHT_SUBSYSTEM_IS_IN_POLARISATION_MODE)
        {
            _bufferS1 = ALLOC_ARRAY(float, width * height * _spectralChannels);
            _bufferS2 = ALLOC_ARRAY(float, width * height * _spectralChannels);
            _bufferS3 = ALLOC_ARRAY(float, width * height * _spectralChannels);
        }

#ifdef WRITE_RGB_VERSION
        _bufferRGBA = ALLOC_ARRAY(float, 4 * width * height);
#endif // WRITE_RGB_VERSION
    }
    
    _scanline = ALLOC_ARRAY( ArLightAlpha *, XC(_size) );

    for ( unsigned int i = 0; i < XC(_size); i++ ) {
        _scanline[i] =
            arlightalpha_d_alloc_init_unpolarised(
                art_gv,
                0.0
                );
    }
}


- (void) _getPixelValue
        : (ArSpectrum *) colour
        : (float *) buffer
{
    for ( int c = 0; c < _spectralChannels; c++ )
    {
        buffer[c] = spc_si( art_gv, colour, c );
    }
}


- (void) setPlainImage
        : (IPnt2D) start
        : (ArnPlainImage *) image
{
    ArSpectrum  * spc = spc_alloc( art_gv );

    for ( long y = 0; y < YC(image->size); y++ )
    {
        const long targetY = y + YC(start);

        [ ((ArnLightAlphaImage *)image) getLightAlphaRegion
            :   IPNT2D(0, y)
            :   IVEC2D(XC(image->size), 1)
            :   _scanline
            :   0 ];
    
        
        if ( _containsPolarisationData ) {
            ARREFFRAME_RF_I( _referenceFrame, 0 ) = VEC3D( 1.0, 0.0, 0.0 );
            ARREFFRAME_RF_I( _referenceFrame, 1 ) = VEC3D( 0.0, 1.0, 0.0 );
                        
            for (long x = 0; x < XC(image->size); x++) {
                const long targetX = x + XC(start);

                ArStokesVector  * sv = arstokesvector_alloc( art_gv );

                arlightalpha_l_to_sv(
                    art_gv,
                    _scanline[ x ],
                    sv
                    );

                for (int c = 0; c < _spectralChannels; c++) {
                    _bufferS0[_spectralChannels * (targetY * XC(_size) + targetX) + c] = spc_si( art_gv, ARSV_I( *sv, 0), c );
                    _bufferS1[_spectralChannels * (targetY * XC(_size) + targetX) + c] = spc_si( art_gv, ARSV_I( *sv, 1), c );
                    _bufferS2[_spectralChannels * (targetY * XC(_size) + targetX) + c] = spc_si( art_gv, ARSV_I( *sv, 2), c );
                    _bufferS3[_spectralChannels * (targetY * XC(_size) + targetX) + c] = spc_si( art_gv, ARSV_I( *sv, 3), c );
                }
                
#ifdef WRITE_RGB_VERSION
                ArRGBA  rgba;
                
                spc_to_rgba(
                        art_gv,
                        ARSV_I( *sv, 0),
                    & rgba
                    );
                
                _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 0] = ARRGBA_R(rgba);
                _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 1] = ARRGBA_G(rgba);
                _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 2] = ARRGBA_B(rgba);
                _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 3] = ARRGBA_A(rgba);
#endif // WRITE_RGB_VERSION
                
                arstokesvector_free( art_gv, sv );
            }
        } else {
            for (long x = 0; x < XC(image->size); x++) {
                const long targetX = x + XC(start);

                if ( _dataType == ardt_rgba ) { // art_foundation_isr(art_gv) ?
                    ArRGBA  rgba;

                    arlightalpha_to_spc(
                          art_gv,
                          _scanline[x],
                          spc
                        );

                    spc_to_rgba(
                          art_gv,
                          spc,
                        & rgba
                        );

                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 0] = ARRGBA_R(rgba);
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 1] = ARRGBA_G(rgba);
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 2] = ARRGBA_B(rgba);
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 3] = ARRGBA_A(rgba);
                } else {
                    arlightalpha_to_spc(
                          art_gv,
                          _scanline[x],
                          spc
                        );
                    
                    for ( int c = 0; c < _spectralChannels; c++ )
                    {
                        _bufferS0[_spectralChannels * (targetY * XC(_size) + targetX) + c] = spc_si( art_gv, spc, c );
                    }
#ifdef WRITE_RGB_VERSION
                    ArRGBA  rgba;
                    
                    spc_to_rgba(
                          art_gv,
                          spc,
                        & rgba
                        );
                    
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 0] = ARRGBA_R(rgba);
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 1] = ARRGBA_G(rgba);
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 2] = ARRGBA_B(rgba);
                    _bufferRGBA[4 * (targetY * XC(_size) + targetX) + 3] = ARRGBA_A(rgba);
#endif // WRITE_RGB_VERSION
                }
            }
        }
    }
    
    spc_free(art_gv, spc);
}


- (void) close
{
    // Gather metadata
    const IVec2D size = [ _imageInfo size ];
    const int width = XC(size);
    const int height = YC(size);
        
    char * createdByString = NULL;
    char * creationDateStr = NULL;

    const char * creationPlatform = ART_APPLICATION_PLATFORM_DESCRIPTION;
    const char * creationCommandLine = ART_APPLICATION_ENTIRE_COMMANDLINE;
    const char * renderTime = [ _imageInfo rendertimeString ];
    const char * samplesPerPixels = [ _imageInfo samplecountString ];


    time_t timer = time(NULL); //gets time of day
    struct tm *tblock = localtime(&timer); //converts date/time to a structure
    //   File creation information
    asprintf(
        & createdByString,
          "%s, ART %s",
          ART_APPLICATION_NAME,
          art_version_string
        );

    asprintf(
         & creationDateStr,
           "%.2d.%.2d.%d %.2d:%.2d\n",
           tblock->tm_mday,
           tblock->tm_mon + 1,
           tblock->tm_year + 1900,
           tblock->tm_hour,
           tblock->tm_min);

    const char* metadata_keys[6] = {
        "File created by",
        "Platform",
        "Command line",
        "Creation date",
        "Render time",
        "Samples per pixel"
    };

    const char* metadata_values[6] = {
        createdByString,
        creationPlatform,
        creationCommandLine,
        creationDateStr,
        renderTime,
        samplesPerPixels
    };

    // Retrieve wavelengths
    double * wavelengths = ALLOC_ARRAY(double, _spectralChannels);

    for (int i = 0; i < _spectralChannels; i++) {
        float central = 0.F;
        
        switch(_spectralChannels) {
            case 8:
                central = s8_channel_center( art_gv, i );
                break;
            case 11:
                central = s11_channel_center( art_gv, i );
                break;
            case 18:
                central = s18_channel_center( art_gv, i );
                break;
            case 46:
                central = s46_channel_center( art_gv, i );
                break;
            default:
                ART_ERRORHANDLING_FATAL_ERROR(
                        "Unrecognised number of spectral channels %d requested",
                        _spectralChannels
                );
        }

        wavelengths[i] = central * 1e9;
    }

    const float* spectralBuffers[] = {
        _bufferS0, _bufferS1, _bufferS2, _bufferS3
    };

    saveEXR(
        [file name], 
        XC(_size), YC(_size), 
        _bufferRGBA, 
        spectralBuffers,
        wavelengths,
        _spectralChannels,
        metadata_keys,
        metadata_values,
        6
        );

    FREE(createdByString);
    FREE(creationDateStr);
    FREE_ARRAY(wavelengths);
}

- (void) dealloc
{
    FREE_ARRAY(_bufferRGBA);
    FREE_ARRAY(_bufferS0);
    FREE_ARRAY(_bufferS1);
    FREE_ARRAY(_bufferS2);
    FREE_ARRAY(_bufferS3);
    
    for ( unsigned int i = 0; i < XC(_size); i++ ) {
        arlightalpha_free(art_gv, _scanline[i]);
    }
    
    FREE_ARRAY(_scanline);
    [_imageInfo release];

    
    // if ( _exr_cpp_vars ) {
    //     if (_exr_cpp_vars->exrfile_out) {
    //         delete _exr_cpp_vars->exrfile_out;
    //     }
    //     FREE(_exr_cpp_vars);
    // }

    [ super dealloc ];
}

@end

#endif // ! ART_WITH_OPENEXR

// ===========================================================================
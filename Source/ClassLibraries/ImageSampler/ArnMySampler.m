#define ART_MODULE_NAME     ArnMySampler




#import "ArnMySampler.h"

#import "FoundationAssertionMacros.h"
#import "ApplicationSupport.h"
#import "ArnImageSamplerCommonMacros.h"

#import "ART_ImageFileFormat.h"
#import "ART_ARM_Interface.h"

#include <signal.h>
#include <unistd.h>
#include <termios.h> 


#define TILE_CONSTANT 3
//TODO:handle fail states


pthread_mutex_t  * signal_handler_mutex;
pthread_cond_t   * signal_handler_cond;

volatile sig_atomic_t  received_signal;

int _image_sampler_received_signal(
        )
{
    return received_signal;
}

void _image_sampler_reset_received_signals(
        )
{
    received_signal = 0;
}

void _image_sampler_sigusr1_handler(
        int  sig
        )
{
    (void) sig;
    
    received_signal = 1;
    pthread_mutex_lock( signal_handler_mutex );
    pthread_cond_signal( signal_handler_cond );
    pthread_mutex_unlock( signal_handler_mutex );
}

void _image_sampler_sigusr2_handler(
        int  sig
        )
{
    (void) sig;
    
    received_signal = 2;
    pthread_mutex_lock( signal_handler_mutex );
    pthread_cond_signal( signal_handler_cond );
    pthread_mutex_unlock( signal_handler_mutex );
}

void _image_sampler_sigint_handler(
        int  sig
        )
{
    (void) sig;
    
    received_signal = 3;
    pthread_mutex_lock( signal_handler_mutex );
    pthread_cond_signal( signal_handler_cond );
    pthread_mutex_unlock( signal_handler_mutex );
}





bool is_poison(task_t *t){
    return NULL==t->work_tile;
}

struct queue_t{
    size_t tail,head,length,max_size;
    task_t** data;    
};
typedef struct queue_t queue_t;

int div_roundup(int divident,int divisor){
    return (divident+(divisor-1))/divisor;
}

bool init_queue(queue_t* q,size_t task_number){

    q->tail=0;
    q->head=0;
    q->length=0;
    q->max_size=task_number;
    q->data=ALLOC_ARRAY(task_t*, task_number);
    
    return (bool)q->data;
}

void free_queue(queue_t* q){
    FREE_ARRAY(q->data);
}

void pop_queue(queue_t* q){
    size_t tail=q->tail;
    tail++;
    q->tail=tail%q->max_size;
    q->length--;
}

task_t* peek_queue(queue_t* q){
    return q->data[q->tail];
}

void push_queue(queue_t* q,task_t* t){
    size_t head=q->head;
    task_t** data=q->data;
    data[head]=t;
    head++;
    q->head=(head==(*q).max_size)?0:head;
    q->length++;
}

#define SYNC_LOCK (q->lock)
#define SYNC_LOCK_PTR (&q->lock)
#define SYNC_COND (q->cond_var)
#define SYNC_COND_PTR (&q->cond_var)
#define SYNC_QUEUE (*q->current)
#define SYNC_QUEUE_PTR (q->current)
struct render_queue_t{
    queue_t queue;
    queue_t* current;
    pthread_mutex_t lock;
    pthread_cond_t cond_var;
} render_queue;
typedef struct render_queue_t render_queue_t;

bool init_render_queue(render_queue_t* q,size_t task_number){
    SYNC_QUEUE_PTR=&q->queue;
    init_queue(SYNC_QUEUE_PTR,task_number);
    pthread_mutex_init(SYNC_LOCK_PTR, NULL);
    pthread_cond_init(SYNC_COND_PTR, NULL);
    
    return true;
}

void free_render_queue(render_queue_t* q){
    free_queue(SYNC_QUEUE_PTR);
    pthread_mutex_destroy(SYNC_LOCK_PTR);
    pthread_cond_destroy(SYNC_COND_PTR);
}

task_t* pop_render_queue(render_queue_t* q){
    pthread_mutex_lock(SYNC_LOCK_PTR);
    while(SYNC_QUEUE.length==0)
        pthread_cond_wait(SYNC_COND_PTR, SYNC_LOCK_PTR);
    task_t* ret=peek_queue(SYNC_QUEUE_PTR);
    if (!is_poison(ret))
        pop_queue(SYNC_QUEUE_PTR);
    pthread_mutex_unlock(SYNC_LOCK_PTR);
    return ret;
}

void push_render_queue(render_queue_t*restrict q,task_t * restrict task){
    pthread_mutex_lock(SYNC_LOCK_PTR);
    
    push_queue(SYNC_QUEUE_PTR, task);
    
    pthread_mutex_unlock(SYNC_LOCK_PTR);
    pthread_cond_broadcast(SYNC_COND_PTR);
}


struct merge_queue_t{
    queue_t queue1,queue2;
    queue_t* current,*inactive;;
     
    pthread_mutex_t lock;
    pthread_cond_t cond_var;
} merge_queue;
typedef struct merge_queue_t merge_queue_t;

bool init_merge_queue(merge_queue_t* q,size_t task_number){
    SYNC_QUEUE_PTR=&q->queue1;
    q->inactive=&q->queue2;
    init_queue(&q->queue1,task_number);
    init_queue(&q->queue2,task_number);
    pthread_mutex_init(SYNC_LOCK_PTR, NULL);
    pthread_cond_init(SYNC_COND_PTR, NULL);
    
    return true;
}

void free_merge_queue(merge_queue_t* q){
    free_queue(&q->queue1);
    free_queue(&q->queue2);
    pthread_mutex_destroy(SYNC_LOCK_PTR);
    pthread_cond_destroy(SYNC_COND_PTR);
}



void push_merge_queue(merge_queue_t* q,task_t* task){
    pthread_mutex_lock(SYNC_LOCK_PTR);
    push_queue(SYNC_QUEUE_PTR, task);
    pthread_mutex_unlock(SYNC_LOCK_PTR);
    pthread_cond_signal(SYNC_COND_PTR);
}

void swap_merge_queue(merge_queue_t* q){
    pthread_mutex_lock(SYNC_LOCK_PTR);
    while(SYNC_QUEUE.length==0){
        pthread_cond_wait(SYNC_COND_PTR, SYNC_LOCK_PTR);
    }
    queue_t* tmp =SYNC_QUEUE_PTR;
    SYNC_QUEUE_PTR=q->inactive;
    q->inactive=tmp;
    pthread_mutex_unlock(SYNC_LOCK_PTR);
}




ART_MODULE_INITIALISATION_FUNCTION
(
    (void) art_gv;
    [ ArnMySampler registerWithRuntime ];
)


ART_NO_MODULE_SHUTDOWN_FUNCTION_NECESSARY

@implementation ArnMySampler

- (void) init_tile
    :(tile_t*) tile
    :(IVec2D) size
{
    tile->size=size;
    tile->image=ALLOC_ARRAY(ArnLightAlphaImage*, numberOfImagesToWrite);
    for (unsigned int i=0 ; i <numberOfImagesToWrite; i++) {
        tile->image[i]=[ ALLOC_OBJECT(ArnLightAlphaImage)
                    initWithSize
                    :   tile->size
                    ];
    }
    tile->samples=ALLOC_ARRAY(
            double,
            numberOfImagesToWrite*XC(tile->size) * YC(tile->size)
            );
    [self clean_tile:tile];
}

- (void) clean_tile
    :(tile_t*) tile
{
    for ( unsigned int i=0 ; i <numberOfImagesToWrite; i++) {
        for ( int y = 0; y < YC(tile->size); y++ )
        {
            for ( int x = 0; x < XC(tile->size); x++ )
            {
                arlightalpha_l_init_l(
                        art_gv,
                        ARLIGHTALPHA_NONE_A0,
                        tile->image[i]->data[x + y*XC(tile->size)]
                    );
                tile->samples[i*XC(tile->size)*YC(tile->size)+x +y*XC(tile->size)]=0.0;
            }
        }
    }
}
- (void) free_tile
    :(tile_t*) tile
{
    for (unsigned int i=0 ; i <numberOfImagesToWrite; i++) {
        RELEASE_OBJECT(tile->image[i]);
    }
    FREE_ARRAY(tile->image);
    FREE_ARRAY(tile->samples);
}


- (BOOL) make_task
    :(task_t*) t
{
    if (finishedGeneratingRenderTasks){
        if (poisoned_render) {
            return false;
        }else{
            t->work_tile=NULL;
            t->window=NULL;
            t->samples=0;
            poisoned_render=true;
            return true;
        }
    }else{
        t->samples=samples_per_window;
        t->window=&render_windows[window_iterator];
        t->sample_start=samples_issued;
        [self task_next_iteration];
        return true;
    }
    return false;
}
- (void) task_next_iteration
{
    window_iterator++;
    if(window_iterator==tiles_X*tiles_Y){
        [ sampleCounter step
            :   samples_per_window
            ];
        window_iterator=0;
        samples_issued+=samples_per_window;
        samples_per_window=samples_per_window_adaptive;
        samples_per_window= MIN(overallNumberOfSamplesPerPixel-samples_issued,samples_per_window);
        if(samples_per_window==0){
            finishedGeneratingRenderTasks=true;
        }
    }
}



ARPCONCRETECLASS_DEFAULT_IMPLEMENTATION(ArnMySampler)
ARPACTION_DEFAULT_IMPLEMENTATION(ArnMySampler)

- (void) setupInternalVariables
{
    deterministicWavelengths = NO;
    finishedGeneratingRenderTasks=NO;
    renderThreadsShouldTerminate = NO;
    workingThreadsAreDone=NO;
    wavelengthSteps = 1;
    window_iterator=0;
    samples_per_window=1024;
    samples_per_window_adaptive=samples_per_window;
    samples_issued=0;
    samples_per_window= MIN(overallNumberOfSamplesPerPixel-samples_issued,samples_per_window);
        if(samples_per_window==0){
            finishedGeneratingRenderTasks=true;
        }
}
- (id) init
        : (ArNode <ArpPathspaceIntegrator> * ) newPathspaceIntegrator
        : (ArNode <ArpReconstructionKernel> *) newReconstructionKernel
        : (unsigned int) newNumberOfSamples
        : (int) newRandomValueGeneration
{

    self =
        [ super init
            :   HARD_NODE_REFERENCE(newPathspaceIntegrator)
            :   HARD_NODE_REFERENCE(newReconstructionKernel)
            ];

    if ( self )
    {
        
        numberOfRenderThreads = art_maximum_number_of_working_threads(art_gv);
        overallNumberOfSamplesPerPixel = newNumberOfSamples;
        randomValueGeneration = newRandomValueGeneration;        
        [self setupInternalVariables];
    }
    return self;
}

- (id) copy
{
    ArnMySampler * copiedInstance = [ super copy ];

    ART__CODE_IS_WORK_IN_PROGRESS__EXIT_WITH_ERROR

    return copiedInstance;
}

- (id) deepSemanticCopy
        : (ArnGraphTraversal *) traversal
{
    ArnMySampler  * copiedInstance =
        [ super deepSemanticCopy
            :   traversal
            ];

    ART__CODE_IS_WORK_IN_PROGRESS__EXIT_WITH_ERROR

    return copiedInstance;
}

#define SAMPLE_SPLATTING_FACTOR( __k, __i ) \
    sampleSplattingFactor[ (__k) * splattingKernelArea + (__i) ]

#define SAMPLE_SPLATTING_FACTOR_UV( __k, __u, __v ) \
    SAMPLE_SPLATTING_FACTOR( __k, (__u) * splattingKernelWidth + (__v) )

- (void) prepareForSampling
        : (ArNode <ArpWorld> *) nWorld
        : (ArNode <ArpCamera > *) nCamera
        : (ArNode <ArpImageWriter> **) image
        : (int) numberOfResultImages
{
    (void)nWorld;
    (void)nCamera;
    
    pthread_barrier_init(&renderingDone, NULL, numberOfRenderThreads+1);
    pthread_barrier_init(&mergingDone, NULL, 2);
    pthread_barrier_init(&final_write_barrier, NULL, 2);
    
    pthread_mutex_init( & writeThreadMutex, NULL );
    pthread_cond_init( & writeThreadCond, NULL);
    sem_init(&tonemapAndOpenThreadSem, 0, 1);

    signal_handler_mutex = & writeThreadMutex;
    signal_handler_cond  = & writeThreadCond;
    if ( overallNumberOfSamplesPerPixel == 0 )
    {
        asprintf(
            & preSamplingMessage,
              "---   interactive mode on, open ended sampling, press t to terminate   ---\n"
            );
        overallNumberOfSamplesPerPixel=10000000;
    }
    else
    {
        asprintf(
            & preSamplingMessage,
              "---   interactive mode on, goal are %d spp   ---\n",
              overallNumberOfSamplesPerPixel
            );
    }
    numberOfImagesToWrite=numberOfResultImages;
    
    sampleCounter =
        [ ALLOC_INIT_OBJECT(ArcSampleCounter)
            :  ART_GLOBAL_REPORTER
            :  GATHERING_ESTIMATOR
            :  self
            :  overallNumberOfSamplesPerPixel
            ];
    randomGenerator =
        ALLOC_ARRAY(
            ArcObject <ArpRandomGenerator> *,
            numberOfRenderThreads
            );

    //   Note that the thread RNGs initialised by the following
    //   loop are all initialised to different starting seeds.
    //   ART RNGs call the 'master RNG' of the entire system when
    //   they are created, to obtain a unique starting value.
    //init generators
    for ( unsigned int i = 0; i < numberOfRenderThreads; i++)
    {
        //ASK we dont know number of samples per thread
        randomGenerator[i] =
            ARCRANDOMGENERATOR_NEW(
                randomValueGeneration,
                overallNumberOfSamplesPerPixel,
                ART_GLOBAL_REPORTER
                );

        ASSERT_CLASS_OR_SUBCLASS_MEMBERSHIP(
            randomGenerator[i],
            ArcRandomGenerator
            );
    }

    outputImage =
        ALLOC_ARRAY(ArNode <ArpImageWriter> *, numberOfResultImages);
    for ( int i = 0; i < numberOfResultImages; i++ )
        outputImage[i] = image[i];
    imageSize = [ outputImage[0] size ];
    imageOrigin = [ outputImage[0] origin ];

    //get valid pixels bool array.
    //ASK: difference in scanline
    //size of this is 2MB for 1900x1080p picture if bool=1B
    unfinished=ALLOC_ARRAY(BOOL, YC(imageSize)*XC(imageSize));
    for ( int y = 0; y < YC(imageSize); y++ )
    {
    
        for ( int x = 0; x < XC(imageSize); x++ )
        {
            ArReferenceFrame  referenceFrame;
            Ray3D             ray;
            
            BOOL  corner00 =
                [ camera getWorldspaceRay
                    : & VEC2D(
                        x + 0,
                        y + 0
                        )
                    :   randomGenerator[0]
                    : & referenceFrame
                    : & ray
                    ];

            BOOL  corner01 =
                [ camera getWorldspaceRay
                    : & VEC2D(
                        x + 0,
                        y + 1
                        )
                    :   randomGenerator[0]
                    : & referenceFrame
                    : & ray
                    ];

            BOOL  corner10 =
                [ camera getWorldspaceRay
                    : & VEC2D(
                        x + 1,
                        y + 0
                        )
                    :   randomGenerator[0]
                    : & referenceFrame
                    : & ray
                    ];

            BOOL  corner11 =
                [ camera getWorldspaceRay
                    : & VEC2D(
                        x + 1,
                        y + 1
                        )
                    :   randomGenerator[0]
                    : & referenceFrame
                    : & ray
                    ];
            
            //   If any of the corners is a valid ray, the pixel has to
            //   be looked at
            
            unfinished[x + y*XC(imageSize)] = corner00 || corner01 || corner10 || corner11;
        }
    }

    pathspaceIntegrator =
        ALLOC_ARRAY(
            ArNode <ArpPathspaceIntegrator> *,
            numberOfRenderThreads
            );

    pathspaceResultFreelist =
        ALLOC_ARRAY(
            ArFreelist,
            numberOfRenderThreads
            );

    for ( unsigned int i = 0; i < numberOfRenderThreads; i++)
    {
        ARFREELIST_INIT_FOR_TYPE(
            pathspaceResultFreelist[i],
            arpathspaceresult,
            128
            );

        pathspaceIntegrator[i] =
            [ GATHERING_ESTIMATOR copy ];

        [ pathspaceIntegrator[i] setGatheringResultFreelist
            : & pathspaceResultFreelist[i]
            ];

        [ pathspaceIntegrator[i] setRandomGenerator
            :   randomGenerator[i]
            ];

        [ pathspaceIntegrator[i] prepareForEstimation
            :   world
            :   lightsources
            :   [ camera eye ]
            :   [ camera near ]
            :   overallNumberOfSamplesPerPixel
            :   ART_GLOBAL_REPORTER
            ];
    }

    arwavelength_sampling_data_from_current_ISR_s(
          art_gv,
        & spectralSamplingData
        );

    sps_splatting_data_from_current_ISR_s(
          art_gv,
        & spectralSplattingData
        );
    [self init_tile: &merge_image : imageSize];
    
    tile_size=IVEC2D(16, 16);
    
    div_roundup(XC(imageSize)-XC(imageOrigin), XC(tile_size));
    
    tiles_X=div_roundup(XC(imageSize)-XC(imageOrigin), XC(tile_size));
    tiles_Y=div_roundup(YC(imageSize)-YC(imageOrigin), YC(tile_size));
    render_windows= ALLOC_ARRAY(image_window_t, tiles_X*tiles_Y);

    int y_start=YC(imageOrigin);
    for (unsigned int y=0; y<tiles_Y; y++) {
        int x_start=XC(imageOrigin);
        for (unsigned int x=0; x<tiles_X; x++) {
            image_window_t* curr=&render_windows[y*tiles_X+x];
            curr->start=IVEC2D(x_start, y_start);
            int x_end=MIN(x_start+XC(tile_size), XC(imageSize));
            int y_end=MIN(y_start+YC(tile_size), YC(imageSize));
            
            curr->end=IVEC2D(x_end, y_end);
            x_start=x_end;
        }
        y_start=MIN(y_start+YC(tile_size), YC(imageSize));
    }  
  
    splattingKernelWidth  = [ RECONSTRUCTION_KERNEL supportSize ];
    splattingKernelWidthDiv2 = splattingKernelWidth / 2;
    splattingKernelArea   = M_SQR( splattingKernelWidth );
    splattingKernelOffset = (splattingKernelWidth - 1) / 2;
    IVec2D padded_tile_size=IVEC2D(XC(tile_size)+2*splattingKernelOffset,YC(tile_size)+2*splattingKernelOffset);
    buffer_size=TILE_CONSTANT*numberOfRenderThreads;
    tiles = ALLOC_ARRAY(
            tile_t,
            buffer_size
            );
    for ( size_t i = 0;
          i < buffer_size;
          i++ )
    {
        [self init_tile: &tiles[i] : padded_tile_size];
    }
    init_render_queue(&render_queue, buffer_size);
    init_merge_queue(&merge_queue, buffer_size);
    task_buffer=ALLOC_ARRAY(task_t, buffer_size);
    for (size_t i =0; i< buffer_size; i++) {
        task_buffer[i].work_tile=&tiles[i];
        if([self make_task: &task_buffer[i]]){
            push_render_queue(&render_queue, &task_buffer[i]);
        }
    }


    
    // //   2D sample coordinates are pre-generated for the entire packet

    // //   CAVEAT: they are the same for all packets - but given the huge
    // //           packet sizes, this should never really be an issue!
    // //           And as long as you cast less than DEFAULT_PACKET_SIZE
    // //           rays, everything is as expected anyway - each ray has
    // //           unique 2D subpixel coordinates in that case.

    numberOfSubpixelSamples =
        M_MIN( IMAGE_SAMPLER_MAX_SUBPIXEL_SAMPLES, overallNumberOfSamplesPerPixel);
    
    sampleCoord = ALLOC_ARRAY( Pnt2D, numberOfSubpixelSamples );
    // //   Actual generation of the 2D sample coordinates

    // //   Note that we reset the random generator sequence counter for each
    // //   2D coordinate - they all should be from the first two sequences the
    // //   generator has to offer!
    
    for ( unsigned int i = 0; i < numberOfSubpixelSamples; i++ )
    {
        
        [ randomGenerator[0] resetSequenceIDs ];

        [ randomGenerator[0] getValuesFromNewSequences
            : & XC( sampleCoord[i] )
            : & YC( sampleCoord[i] )
            ];
    }
    //   We remember the sequence ID of the generator after it did the last
    //   coordinate - rendering always has to start there!
    

    startingSequenceID = [ randomGenerator[0] currentSequenceID ];

    //   Sample splatting factors: these are the contribution factors for each
    //   pre-computed 2D sample coordinate. They do not change between pixels,
    //   so pre-computing the splatting kernel influence for each of them
    //   is faster than re-evaluating this every time a sample gets splatted.
    
    if ( splattingKernelWidth > 1 )
    {
        sampleSplattingFactor =
            ALLOC_ARRAY( double, splattingKernelArea * numberOfSubpixelSamples );

        for ( unsigned int i = 0; i < numberOfSubpixelSamples; i++ )
        {
            for ( unsigned int u = 0; u < splattingKernelWidth; u++ )
            {
                double  dY = 1.0 * u - splattingKernelOffset;

                for ( unsigned int v = 0; v < splattingKernelWidth; v++ )
                {
                    double  dX = 1.0 * v - splattingKernelOffset;

                    Pnt2D  localCoord;

                    XC(localCoord) = XC(sampleCoord[i]) - dX - 0.5;
                    YC(localCoord) = YC(sampleCoord[i]) - dY - 0.5;

                    SAMPLE_SPLATTING_FACTOR_UV( i, u, v ) =
                        [ RECONSTRUCTION_KERNEL valueAt
                            : & localCoord
                            ];

                } // splatting kernel v coord for loop
            } // splatting kernel u coord for loop
        } // i - number of samples per packet
        sampleSplattingOffset =
            ALLOC_ARRAY( IPnt2D, splattingKernelArea );

        for ( unsigned int u = 0; u < splattingKernelWidth; u++ )
            for ( unsigned int v = 0; v < splattingKernelWidth; v++ )
            {
                XC( sampleSplattingOffset[ u * splattingKernelWidth + v ] )
                    = u - splattingKernelOffset;
                YC( sampleSplattingOffset[ u * splattingKernelWidth + v ] )
                    = v - splattingKernelOffset;
            }
    }

    
}

- (void) sampleImage
        : (ArNode <ArpWorld> *) world
        : (ArNode <ArpCamera > *) camera
        : (ArNode <ArpImageWriter> **) image
        : (int) numberOfResultImages
{
    



    // pthread_mutex_lock( & writeThreadMutex );

    // //   This function sets the stage for the rendering processes to do their
    // //   work, starts them, and then sleeps until they are done.
    
    // //   Detach n render threads.

    [ sampleCounter start ];

    for ( unsigned int i = 0; i < numberOfRenderThreads; i++ )
    {
        ArcUnsignedInteger  * index = [ ALLOC_INIT_OBJECT(ArcUnsignedInteger) : i ];

        if ( ! art_thread_detach(@selector(renderThread:), self,  index))
            ART_ERRORHANDLING_FATAL_ERROR(
                "could not detach rendering thread %d",
                i
                );
    }
    
    {
        int i=numberOfRenderThreads;
        ArcUnsignedInteger  * index = [ ALLOC_INIT_OBJECT(ArcUnsignedInteger) : i ];

        if ( ! art_thread_detach(@selector(mergeThread:), self,  index))
            ART_ERRORHANDLING_FATAL_ERROR(
                "could not detach rendering thread %d",
                i
                );
    }
    {
        int i=numberOfRenderThreads+1;
        ArcUnsignedInteger  * index = [ ALLOC_INIT_OBJECT(ArcUnsignedInteger) : i ];

        if ( ! art_thread_detach(@selector(terminalIOThread:), self,  index))
        ART_ERRORHANDLING_FATAL_ERROR(
            "could not detach terminal I/O thread"
            );
    }
    {
        int i=numberOfRenderThreads+2;
        ArcUnsignedInteger  * index = [ ALLOC_INIT_OBJECT(ArcUnsignedInteger) : i ];

        if ( ! art_thread_detach(@selector(writeThread:), self,  index))
        ART_ERRORHANDLING_FATAL_ERROR(
            "could not detach terminal I/O thread"
            );
    }


    struct sigaction sa;

    _image_sampler_reset_received_signals();

    sa.sa_handler = _image_sampler_sigusr1_handler;
    sa.sa_flags = 0;
    sigemptyset( & sa.sa_mask );

    if ( sigaction( SIGUSR1, & sa, NULL ) == -1 )
    {
        ART_ERRORHANDLING_FATAL_ERROR(
            "could not install handler for SIGUSR1"
            );
    }

    sa.sa_handler = _image_sampler_sigusr2_handler;

    if ( sigaction( SIGUSR2, & sa, NULL ) == -1 )
    {
        ART_ERRORHANDLING_FATAL_ERROR(
            "could not install handler for SIGUSR2"
            );
    }

    sa.sa_handler = _image_sampler_sigint_handler;

    if ( sigaction( SIGINT, & sa, NULL ) == -1 )
    {
        ART_ERRORHANDLING_FATAL_ERROR(
            "could not install handler for SIGINT"
            );
    }

    if( pipe( read_thread_pipe ) == -1 )
    {
        fprintf(stderr, "Error creating pipe to I/O thread\n");
    }

    // //   Wait for the results to come in, and assemble them into a final
    // //   result image.
    
    

    // /* ------------------------------------------------------------------
    //     IMPORTANT: unlike all other timings done in ART the duration of
    //     the main image writing thread (from which the duration of the
    //     whole ray-based rendering pass is computed) is based on elapsed
    //     time, and not on system time used.
    //     The reason for this is that the multi-threaded nature of the
    //     pixel sampler makes most other options pretty useless. The
    //     user time of the write thread is far less than the true rendering
    //     time - it spends most of its time sleeping and waiting for the
    //     rendering thread(s) - while the user time of the rendering
    //     thread(s) might differ by a considerable amount. If you have
    //     too much time on your hands you can try computing the average
    //     of the rendering thread user times and returning _that_. :-)
    // ---------------------------------------------------------------aw- */

    

    artime_now( & beginTime );

    pthread_barrier_wait(&renderingDone);
    task_t merge_poison;
    merge_poison.work_tile=NULL;
    push_merge_queue(&merge_queue, &merge_poison);

    pthread_barrier_wait(&mergingDone);
    
    //ASK WHERE EXACTLY IS A GOOD PLACE FOR THIS?
    write( read_thread_pipe[1], "q", 1 );
    pthread_mutex_lock(&writeThreadMutex);
    workingThreadsAreDone=YES;
    pthread_cond_signal(&writeThreadCond);
    pthread_mutex_unlock(&writeThreadMutex);
    
    // //   The basic structure of the threaded renderer is such that it
    // //   is able to write partially-done images even before all threads
    // //   terminate. Writing of such intermediate images is triggered via
    // //   user signals, which have to be reset after use.
    
    

    // //   This shuts down the I/O watching thread for interactive mode
    
    
    
    pthread_barrier_wait(&final_write_barrier);
    
}
- (void)renderThread
    : (ArcUnsignedInteger *) threadIndex
{
    
    NSAutoreleasePool  * threadPool;
    threadPool = [ [ NSAutoreleasePool alloc ] init ];
    (void) threadPool;
    
    while(!renderThreadsShouldTerminate){
        task_t* curr_task= pop_render_queue(&render_queue);
        if(is_poison(curr_task))
            break;
        [self render_task : curr_task: threadIndex];
        push_merge_queue(&merge_queue, curr_task);
    }
    
    pthread_barrier_wait(&renderingDone);
}

typedef struct ArPixelID
{
    long   globalRandomSeed;
    int    threadIndex;
    int    sampleIndex;
    Pnt2D  pixelCoord;
}
ArPixelID;
-(void) render_task
    :(task_t*) t
    : (ArcUnsignedInteger *) threadIndex
{
    [self clean_tile : t->work_tile];
    ArPathspaceResult  ** sampleValue =
        ALLOC_ARRAY( ArPathspaceResult *, numberOfImagesToWrite );
    
    ArPixelID  px_id;
    
    px_id.threadIndex = THREAD_INDEX;
    px_id.globalRandomSeed = arrandom_global_seed(art_gv);
    for (int y=YC(t->window->start); y<YC(t->window->end); y++) {
        YC(px_id.pixelCoord) = y ;    
        for (int x=XC(t->window->start); x<XC(t->window->end); x++) {
            XC(px_id.pixelCoord) = x;
            if(!unfinished[x + y*XC(imageSize)])
                continue;
            for(int sample=0;sample<t->samples;sample++){
                int  subpixelIdx = (t->sample_start  +sample) % numberOfSubpixelSamples;

                if ( renderThreadsShouldTerminate )
                {
                    goto FREE_SAMPLE_VALUE;
                }
                for ( int w = 0; w < wavelengthSteps; w++ )
                {
                    [ THREAD_RANDOM_GENERATOR reInitializeWith
                        :   crc32_of_data( & px_id, sizeof(ArPixelID) )
                        ];

                    /* --------------------------------------------------------------
                        We double-check whether a given sample should be
                        included: first the validity of the ray is checked (rays are
                        always valid for normal cameras, but e.g. fisheye cameras
                        have pixels which lie outside the imaged area) and secondly
                        all rays which do not contain plausible radiance information
                        (all components > 0) are simply not used.

                        The latter check should not be necessary in a perfect world,
                        but in reality malformed mesh data and other gremlins can
                        lead to artefacts if this is not looked after.
                    ------------------------------------------------------------aw- */

                    BOOL  validSample = FALSE;

                    [ THREAD_RANDOM_GENERATOR setCurrentSequenceID
                        :  startingSequenceID
                        ];

                    Ray3D              ray;
                    ArReferenceFrame   referenceFrame;
                    ArWavelength       wavelength;
                    
                    if ( deterministicWavelengths )
                    {
                        arwavelength_i_deterministic_init_w(
                              art_gv,
                              w,
                            & wavelength
                            );
                    }
                    else
                    {
                        arwavelength_sd_init_w(
                              art_gv,
                            & spectralSamplingData,
                              [ THREAD_RANDOM_GENERATOR valueFromNewSequence ],
                            & wavelength
                            );
                    }
                    BOOL valid_ray=[ camera getWorldspaceRay
                             : & VEC2D(
                                    x + XC(sampleCoord[subpixelIdx]),
                                    y + YC(sampleCoord[subpixelIdx])
                                    )
                             :   THREAD_RANDOM_GENERATOR
                             : & referenceFrame
                             : & ray
                             ];
                    if (valid_ray  )
                    {
                        [ THREAD_PATHSPACE_INTEGRATOR calculateLightSamples
                            : & ray
                            : & wavelength
                            :   sampleValue
                            ];

                        if ( arlightalphasample_l_valid(
                                art_gv,
                                ARPATHSPACERESULT_LIGHTALPHASAMPLE(*sampleValue[0])
                                ) )
                        {
                            if ( LIGHT_SUBSYSTEM_IS_IN_POLARISATION_MODE )
                            {
                                for ( unsigned int im = 0; im < numberOfImagesToWrite; im++ )
                                    arlightsample_realign_to_coaxial_refframe_l(
                                          art_gv,
                                        & referenceFrame,
                                          ARPATHSPACERESULT_LIGHTSAMPLE( *sampleValue[im] )
                                        );
                            }
                            
                            validSample = TRUE;
                        }
                    }
                    else
                    {
                        for ( unsigned int im = 0; im < numberOfImagesToWrite; im++ )
                        {
                            sampleValue[im] =
                                (ArPathspaceResult*) arfreelist_pop(
                                    & pathspaceResultFreelist[THREAD_INDEX]
                                    );
                            
                            ARPATHSPACERESULT_NEXT(*sampleValue[im]) = NULL;
                            
                            arlightalphasample_l_init_l(
                                  art_gv,
                                  ARLIGHTALPHASAMPLE_NONE_A0,
                                  ARPATHSPACERESULT_LIGHTALPHASAMPLE(*sampleValue[im])
                                );
                        }

                        validSample = TRUE;
                    }

                    if ( validSample )
                    {
                        if ( splattingKernelWidth == 1 )
                        {
                            for ( unsigned int im = 0; im < numberOfImagesToWrite; im++ )
                            {
                                int xc=x-XC(t->window->start);
                                int yc=y-YC(t->window->start);
                                IVec2D size=t->work_tile->size;
                                t->work_tile->samples[ 
                                    im*XC(size) * YC(size) 
                                    + yc*XC(size)+xc]+=1.0;
                                           
                                arlightalpha_wsd_sloppy_add_l(
                                      art_gv,
                                      ARPATHSPACERESULT_LIGHTALPHASAMPLE(*sampleValue[im]),
                                    & wavelength,
                                    & spectralSplattingData,
                                      3.0 DEGREES,
                                      t->work_tile->image[im]->data[xc + yc*XC(size)]
                                    );
                            }
                        }
                        else
                        {
                            int xc=x-XC(t->window->start)+splattingKernelOffset;
                            int yc=y-YC(t->window->start)+splattingKernelOffset;
                            IVec2D size=t->work_tile->size;
                            for ( unsigned int im = 0; im < numberOfImagesToWrite; im++ )
                            {
                                for ( unsigned int l = 0; l < splattingKernelArea; l++ )
                                {
                                int  cX = xc + XC( sampleSplattingOffset[l] );
                                int  cY = yc + YC( sampleSplattingOffset[l] );
                                
                                    t->work_tile->samples[ 
                                    im*XC(size) * YC(size) 
                                    + cY*XC(size)+cX]+=SAMPLE_SPLATTING_FACTOR( subpixelIdx, l );
                                    

                                    arlightalpha_dwsd_mul_sloppy_add_l(
                                            art_gv,
                                            SAMPLE_SPLATTING_FACTOR( subpixelIdx, l ),
                                            ARPATHSPACERESULT_LIGHTALPHASAMPLE(*sampleValue[im]),
                                        & wavelength,
                                        & spectralSplattingData,
                                            5.0 DEGREES,
                                            t->work_tile->image[im]->data[cX + cY*XC(size)]
                                        );

                                }
                            }
                        }
                    }

                    for ( unsigned int im = 0; im < numberOfImagesToWrite; im++ )
                    {
                        arpathspaceresult_free_to_freelist(
                              art_gv,
                            & pathspaceResultFreelist[THREAD_INDEX],
                              sampleValue[im]
                            );
                    }
                }
            }
        }
    }
    

    FREE_SAMPLE_VALUE:
    FREE_ARRAY(sampleValue);
}

- (void)mergeThread
    : (ArcUnsignedInteger *) threadIndex
{
    
    NSAutoreleasePool  * threadPool;
    threadPool = [ [ NSAutoreleasePool alloc ] init ];
    (void) threadPool;
    
    while(true){
        swap_merge_queue(&merge_queue);
        
        //todo:adaptively increase samples
        while(merge_queue.inactive->length>0){
            task_t* curr_task=peek_queue(merge_queue.inactive);
            if(is_poison(curr_task))
            {
                goto END;
            }
            pop_queue(merge_queue.inactive);
            [self merge_task : curr_task];
            if([self make_task: curr_task]){
                push_render_queue(&render_queue, curr_task);
            }
        }
    }
    END: 
    pthread_barrier_wait(&mergingDone);
}
-(void) merge_task
    :(task_t*) t
{
    IVec2D ts=t->work_tile->size;

    for ( unsigned int im = 0; im < numberOfImagesToWrite; im++ ){
        for (int y=0; y<YC(ts); y++) {
            for (int x=0; x<XC(ts); x++) {
                int cX=XC(t->window->start)-splattingKernelOffset+x;
                int cY=YC(t->window->start)-splattingKernelOffset+y;
                if (   cX >= 0
                    && cX < XC(imageSize)
                    && cY >= 0
                    && cY < YC(imageSize) )
                {
                    merge_image.samples[
                        cX+cY*XC(imageSize)+im*XC(imageSize)*YC(imageSize)
                        ]+=
                        t->work_tile->samples[im*XC(ts)*YC(ts)+x+y*XC(ts)];
                    
                    
                    arlightalpha_l_add_l(
                        art_gv, 
                        t->work_tile->image[im]->data[x+y*XC(ts)], 
                        merge_image.image[im]->data[cX+cY*XC(imageSize)]);
                }
            }
        }
    }
   
}
- (void)writeThread
    : (ArcUnsignedInteger *) threadIndex
{
    NSAutoreleasePool  * threadPool;
    threadPool = [ [ NSAutoreleasePool alloc ] init ];
    (void) threadPool;
    //ASK:THIS IS MAYBE NOT GOOD
    pthread_mutex_lock( & writeThreadMutex );    
    do
    {
        
        pthread_cond_wait( & writeThreadCond, & writeThreadMutex );
        
        //   we splice all the thread images, and write them to disk
        
        unsigned int  overallNumberOfPixels = YC(imageSize) * XC(imageSize);
        double writeThreadWallClockDuration;
        for ( unsigned int imgIdx = 0; imgIdx < numberOfImagesToWrite; imgIdx++ )
        {
            //   first, we figure out the average number of samples per pixel
            //   this goes into the image statistics that are saved
            //   along with the command line
            
            unsigned int  maxSamples = 0;
            unsigned int  minSamples = 0xffffffff;

            unsigned long int  overallSampleCount = 0;
            unsigned long int  nonzeroPixels = 0;
            
            for ( int y = 0; y < YC(imageSize); y++ )
            {
                for ( int x = 0; x < XC(imageSize); x++ )
                {
                    unsigned int  pixelSampleCount = 0;
                    
                    pixelSampleCount +=merge_image.samples[ 
                        imgIdx*XC(imageSize) * YC(imageSize) + x +y*XC(imageSize)];
                    
                    if ( pixelSampleCount > 0 )
                    {
                        nonzeroPixels++;
                    
                        if ( pixelSampleCount < minSamples )
                            minSamples = pixelSampleCount;
                        
                        overallSampleCount += pixelSampleCount;
                    }
                    
                    if ( pixelSampleCount > maxSamples )
                        maxSamples = pixelSampleCount;
                }
            }

            unsigned int  avgSamples = 0;
            
            if ( nonzeroPixels > 0 )
            {
                avgSamples = (unsigned int)
                    ( (double) overallSampleCount / (double) nonzeroPixels );
            }
            
            char  * samplecountString = NULL;
            
            double  percentageOfZeroPixels =
                ( 1.0 - ( 1.0 * nonzeroPixels / overallNumberOfPixels )) * 100.0;

            if ( percentageOfZeroPixels > 1.0 )
            {
                if ( nonzeroPixels > 0 )
                {
                    asprintf(
                        & samplecountString,
                          "%.0f%% pixels with zero samples,"
                          " rest: %d/%d/%d min/avg/max spp",
                          percentageOfZeroPixels,
                          minSamples,
                          avgSamples,
                          maxSamples
                        );
                }
                else
                {
                    asprintf(
                        & samplecountString,
                          "0 spp"
                        );
                }
            }
            else
            {
                asprintf(
                    & samplecountString,
                      "%d/%d/%d min/avg/max spp",
                      minSamples,
                      avgSamples,
                      maxSamples
                    );
            }

            [ outputImage[imgIdx] setSamplecountString
                :   samplecountString
                ];
            
            FREE( samplecountString );

            artime_now( & endTime );

            writeThreadWallClockDuration =
                  artime_seconds( & endTime )
                - artime_seconds( & beginTime);

            char  * rendertimeString = NULL;
            
            asprintf(
                & rendertimeString,
                  "%.0f seconds",
                  writeThreadWallClockDuration
                );

            [ outputImage[imgIdx] setRendertimeString
                :   rendertimeString
                ];
            
            FREE( rendertimeString );
            ArnLightAlphaImage  * out =
                [ ALLOC_OBJECT(ArnLightAlphaImage)
                    initWithSize
                    :   IVEC2D(XC(imageSize), YC(imageSize))
                    ];
            for ( int y = 0; y < YC(imageSize); y++ )
            {
                for ( int x = 0; x < XC(imageSize); x++ )
                {
                    //ASK:Is there more elegant way
                    arlightalpha_l_init_l(
                          art_gv,
                          ARLIGHTALPHA_NONE_A0,
                          out->data[XC(imageSize)*y+x]
                        );
                    arlightalpha_l_add_l(
                            art_gv,
                            merge_image.image[imgIdx]->data[x +y*XC(imageSize)],
                            out->data[XC(imageSize)*y+x]
                        );
                    double  pixelSampleCount = merge_image.samples[ imgIdx*XC(imageSize) * YC(imageSize) + x +y*XC(imageSize)];

                    
                    
                    //ASK: SHOULD I ALSO ASSERT?
                    // ASSERT_VALID_LIGHTALPHA(
                    //     PIXEL_SAMPLE_VALUE(x,y,threadIdx,imgIdx)
                    //     );
                        
                    
                    
                    

                    if ( pixelSampleCount > 0.0 )
                    {
                        arlightalpha_d_mul_l(
                              art_gv,
                              1.0 / pixelSampleCount,
                              out->data[XC(imageSize)*y+x]
                            );
                    }
                }

                [ outputImage[imgIdx] setPlainImage
                    :   IPNT2D(0,0)
                    :   out
                    ];
            }
            RELEASE_OBJECT(out);
        }
        
        //   We might have been woken by a SIGUSR sent by 'impresario'.
        
        //   USR1 is "write a partially completed image, and go to sleep"
        //   So we just reset the flag, if we were woken by this (work already
        //   done by the code above).
        
        int  receivedSignal =
            _image_sampler_received_signal();
        
        if ( receivedSignal == 1 )
        {
            _image_sampler_reset_received_signals();
        }
        
        //   USR2 writes the current result image, but also tonemaps and
        //   opens it.
        
        if ( receivedSignal == 2 )
        {
            _image_sampler_reset_received_signals();
            
            //   The semaphore basically only ensures that at most, there is only
            //   one tone mapping thread going on at any time.
            //   (so that one cannot shoot down 'artist' by bombarding it with
            //   SIGUSR2 signals)
            
            //   The semaphore is incremented by the tone mapping thread, once it is
            //   done.
            sem_wait(&tonemapAndOpenThreadSem);
            

            

            ArcUnsignedInteger  * index =
                [ ALLOC_INIT_OBJECT(ArcUnsignedInteger)
                    :   numberOfRenderThreads+3
                    ];

            if ( ! art_thread_detach(@selector(tonemapAndOpenProc:), self,  index))
                ART_ERRORHANDLING_FATAL_ERROR(
                    "could not detach intermediate result tone mapping "
                    "& display thread"
                    );
        }

        if ( receivedSignal == 3 )
        {
            _image_sampler_reset_received_signals();
            signal(SIGINT, SIG_DFL);
            renderThreadsShouldTerminate = YES;
        }
    }
    while( ! workingThreadsAreDone );
    artime_now( & endTime );

    int writeThreadWallClockDuration =
          artime_seconds( & endTime )
        - artime_seconds( & beginTime);

    [ sampleCounter stop
        :  writeThreadWallClockDuration
        ];

    
    
    pthread_mutex_unlock( & writeThreadMutex );
    pthread_barrier_wait(&final_write_barrier);
}
- (void) terminalIOThread
    : (ArcUnsignedInteger *) threadIndex
{
    NSAutoreleasePool  * threadPool;
    threadPool = [ [ NSAutoreleasePool alloc ] init ];
    (void) threadPool;
    (void) threadIndex;
    
    if ( art_interactive_mode_permitted( art_gv ) )
    {
        setvbuf(stdout,NULL,_IONBF,0);

        struct termios old_termios, new_termios;
        
        tcgetattr( STDIN_FILENO, & old_termios );

        new_termios = old_termios;

        // disable canonical mode and echo
        new_termios.c_lflag &= (~ICANON & ~ECHO);

        // at least one character must be written before read returns
        new_termios.c_cc[VMIN] = 1;

        // no timeout
        new_termios.c_cc[VTIME] = 0;
        
        tcsetattr( STDIN_FILENO, TCSANOW, & new_termios );

        char  lineA[256]; ssize_t  lenA;
        char  lineB[256]; ssize_t  lenB;
        char * line; ssize_t  len;
        do{
            int  r,nfds = 0;
            fd_set rd, wr, er;

            FD_ZERO(&rd);
            FD_ZERO(&wr);
            FD_ZERO(&er);
            FD_SET(STDIN_FILENO, &rd);
            nfds = M_MAX(nfds, STDIN_FILENO);
            FD_SET(read_thread_pipe[0], &rd);
            nfds = M_MAX(nfds, read_thread_pipe[0]);

            r = select(nfds + 1, &rd, &wr, &er, NULL);
            (void)r;
            lenA = 0;
            lenB = 0;
            
            if ( FD_ISSET(STDIN_FILENO, &rd) )
            {
                lenA=read(STDIN_FILENO,lineA,256); lineA[lenA]='\0';
            }
            
            if ( FD_ISSET(read_thread_pipe[0], &rd) )
            {
                lenB=read(read_thread_pipe[0],lineB,256); lineB[lenB]='\0';
            }
            
            if (lenA > 0 )
            {
                line = lineA;
                len = lenA;
            }
            else
            {
                line = lineB;
                len = lenB;
            }

            if( len > 0 )
            {
                if ( line[0] == 'w' )
                {
                    _image_sampler_sigusr1_handler( SIGUSR1 );
                }

                if ( line[0] == 'd' )
                {
                    _image_sampler_sigusr2_handler( SIGUSR2 );
                }

                if ( line[0] == 't' )
                {
                    _image_sampler_sigint_handler( SIGINT );
                }
            }
        }
        //   we only terminate if we got a 'q' via the pipe, not via the
        //   keyboard
        while( !( line[0] == 'q' && lenB > 0 ) );

        tcsetattr( 0, TCSANOW, & old_termios );
    }
        
}
- (void) tonemapAndOpenProc
    : (ArcUnsignedInteger *) threadIndex
{
    NSAutoreleasePool  * threadPool;
    threadPool = [ [ NSAutoreleasePool alloc ] init ];

    //   minimalist tone mapping action sequence
    
    ArNode <ArpAction>  * actionSequence =
        ACTION_SEQUENCE(
            [ IMAGECONVERSION_RAW_TO_ARTCSP
                removeSource : NO 
            ], 

#ifdef ART_WITH_OPENEXR
            [ IMAGECONVERSION_ARTCSP_TO_EXR
                removeSource : YES
            ],
#else
            STANDARD_GLOBAL_TONEMAPPING_OPERATOR,

            STANDARD_LUMINANCE_CLIPPING, 

            [ IMAGECONVERSION_ARTCSP_TO_TIFF 
                removeSource : YES 
                bitsPerChannel : 8 
            ], 
#endif
            OPEN_RESULT_IMAGE_IN_EXTERNAL_VIEWER_ACTION,

            ACTION_SEQUENCE_END
            );
    
    ArNode <ArpNodeStack>  *  localNodestack =
        ARNNODESTACK( ART_APPLICATION_MAIN_FILENAME );

    //   place input image on node stack, and start stack machine
    //   loop over all output images

    for ( unsigned int imgIdx = 0; imgIdx < numberOfImagesToWrite; imgIdx++ )
    {
        //   we effectively create copies of the actual output images
        //   handing over the originals should work as well, though
        
        ArnFileImage  * image =
            [ FILE_IMAGE
                :   [ (ArnFileImage <ArpImage> *)outputImage[imgIdx] fileName ]
                ];

        [ localNodestack push
            :   HARD_NODE_REFERENCE(image)
            ];
    }

    //   stack machine start
    
    [ actionSequence performOn
        :   localNodestack
        ];

    //   release all things that can be auto-released
    //   (most objects further up were created with autorelease set)
    
    [ threadPool release ];

    //   Release the semaphore
    sem_post(&tonemapAndOpenThreadSem);
}
- (void) cleanupAfterImageSampling
        : (ArNode <ArpWorld> *) world
        : (ArNode <ArpCamera > *) camera
        : (ArNode <ArpImageWriter> **) image
        : (int) numberOfResultImages
{
    //ASK stochastic cleans up in dealloc not in cleanup, where should i do it?
    free_render_queue(&render_queue);
    free_merge_queue(&merge_queue);
    pthread_barrier_destroy(&renderingDone);
    pthread_barrier_destroy(&mergingDone);
    pthread_barrier_destroy(&final_write_barrier);
    pthread_mutex_destroy(&writeThreadMutex);
    pthread_cond_destroy(&writeThreadCond);
    sem_destroy(&tonemapAndOpenThreadSem);
    RELEASE_OBJECT( sampleCounter );

    for ( unsigned int i = 0; i < numberOfRenderThreads; i++ )
    {
        RELEASE_OBJECT( randomGenerator[i] );
    }
    FREE_ARRAY( randomGenerator );
    for ( unsigned int i = 0; i < numberOfRenderThreads; i++ )
    {
        [ pathspaceIntegrator[i] cleanupAfterEstimation: ART_GLOBAL_REPORTER ];

        RELEASE_OBJECT( pathspaceIntegrator[i] );
    }
    
    FREE_ARRAY( pathspaceIntegrator );
    
    FREE_ARRAY( outputImage );
    
    FREE_ARRAY( sampleCoord );

    if ( splattingKernelWidth > 1 )
    {
        FREE_ARRAY( sampleSplattingFactor );
        FREE_ARRAY( sampleSplattingOffset );
    }

    
    for (unsigned int i =0; i<buffer_size; i++) {
        [self free_tile:&tiles[i]];
    }
    [self free_tile:&merge_image];
    FREE_ARRAY(tiles);

    FREE_ARRAY(unfinished);
    FREE_ARRAY(task_buffer);
    FREE_ARRAY(render_windows);

}

- (void) performOn
        : (ArNode <ArpNodeStack> *) nodeStack
{
    ArNodeRef  worldRef  = ARNODEREF_NONE;
    ArNodeRef  cameraRef = ARNODEREF_NONE;
    ArNodeRef  lightRef  = ARNODEREF_NONE;

    ArList     imageRefList = ARLIST_EMPTY;
    
    ArNodeRef  refFromStack;

    //   We pop all the things from the stack we can find, and assign them to
    //   the pointers that need filling.

    while ( ARNODEREF_POINTER( refFromStack = [ nodeStack pop ] ) )
    {
        if ( [ ARNODEREF_POINTER(refFromStack)
                 conformsToArProtocol
                 :   ARPROTOCOL(ArpWorld)
                 ] )
            worldRef = refFromStack;

        if ( [ ARNODEREF_POINTER(refFromStack)
                 conformsToArProtocol
                 :   ARPROTOCOL(ArpBasicImage)
                 ] )
        {
            arlist_add_noderef_at_head( & imageRefList, refFromStack );
        }

        if ( [ ARNODEREF_POINTER(refFromStack)
                 conformsToArProtocol
                 :   ARPROTOCOL(ArpCamera)
                 ] )
            cameraRef = refFromStack;

        if ( [ ARNODEREF_POINTER(refFromStack)
                 conformsToArProtocol
                 :   ARPROTOCOL(ArpLightsourceCollection)
                 ] )
            lightRef = refFromStack;
    }

    int  numberOfResultImages = arlist_length( & imageRefList );

    //   The protocol checks were just done, so casting these things
    //   is safe.
    world  =
        (ArNode <ArpWorld, ArpBBox> *) ARNODEREF_POINTER(worldRef);
    camera =
        (ArNode <ArpCamera> *)ARNODEREF_POINTER(cameraRef);
    lightsources =
        (ArNode <ArpLightsourceCollection> *)ARNODEREF_POINTER(lightRef);


    ArNode <ArpImageWriter>  ** image =
        ALLOC_ARRAY( ArNode <ArpImageWriter> *, numberOfResultImages );
    
    for ( int i = 0; i < numberOfResultImages; i++ )
    {
        ArNodeRef  imageRef = ARNODEREF_NONE;
        
        arlist_pop_noderef( & imageRefList, & imageRef );

        image[i] = (ArNode <ArpImageWriter> *)ARNODEREF_POINTER(imageRef);
        
        [ nodeStack push
            :   HARD_NODE_REFERENCE(image[i])
            ];

        RELEASE_NODE_REF( imageRef );
    }
    
    if ( ! world && [ GATHERING_ESTIMATOR requiresSceneGeometry ] )
        ART_ERRORHANDLING_FATAL_ERROR(
            "no scene geometry found on stack"
            );

    if ( ! camera )
        ART_ERRORHANDLING_FATAL_ERROR(
            "no camera found on stack"
            );

    if ( ! image[0] )
        ART_ERRORHANDLING_FATAL_ERROR(
            "no image found on stack"
            );

    if ( ! lightsources && [ GATHERING_ESTIMATOR requiresLightsourceCollection ] )
        ART_ERRORHANDLING_FATAL_ERROR(
            "no light source collection found on stack"
            );

    [ camera setupForObject
        :   world
        :   ART_GLOBAL_REPORTER
        ];

    [ self prepareForSampling
        :   world
        :   camera
        :   image
        :   numberOfResultImages
        ];
    
    [ self sampleImage
        :   world
        :   camera
        :   image
        :   numberOfResultImages
        ];
    
    [ self cleanupAfterImageSampling
        :   world
        :   camera
        :   image
        :   numberOfResultImages
        ];

    FREE_ARRAY( image );
    RELEASE_NODE_REF( lightRef );
    RELEASE_NODE_REF( cameraRef );
    RELEASE_NODE_REF( worldRef );
}

- (const char *) preSamplingMessage
{
    return preSamplingMessage;
}

- (const char *) postSamplingMessage
{
    return "---   interactive mode off   ---\n";
}

- (void) code
        : (ArcObject <ArpCoder> *) coder
{
    [ super code: coder ];

    [ coder codeUInt: & overallNumberOfSamplesPerPixel ];
    
    if ( [ coder isReading ] )
    {
        numberOfRenderThreads =
            art_maximum_number_of_working_threads(art_gv);
        
        [ self setupInternalVariables ];
    }
    
    [ coder codeInt:  & randomValueGeneration ];
}
- (void) useDeterministicWavelengths
{
    deterministicWavelengths = YES;
    wavelengthSteps = spc_channels(art_gv);
    art_set_hero_samples_to_splat( art_gv, 1 );
}

@end
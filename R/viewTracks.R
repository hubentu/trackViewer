viewTracks <- function(trackList, chromosome, start, end, strand, gr=GRanges(),
                       ignore.strand=TRUE,
                       viewerStyle=trackViewerStyle(), autoOptimizeStyle=FALSE,
                       newpage=TRUE, operator=NULL){
    if(!is.null(operator)){
        if(!operator %in% c("+", "-", "*", "/", "^", "%%")){
            stop('operator must be one of "+", "-", "*", "/", "^", "%%"')
        }
    }
    if(missing(trackList)){
        stop("trackList is required.")
    }
    if(class(trackList)!="trackList" && 
           !((is.list(trackList) && all(sapply(trackList, class)=="track")))){
        stop("trackList must be an object of \"trackList\"
             (See ?trackList) or a list of track")
    }
    if(missing(gr)){
        if(missing(chromosome) || missing(start) || missing(end))
            stop("Please input the coordinate.")
        if(missing(strand) || !strand %in% c("+", "-"))
            strand <- "*"
    }else{
        if(class(gr)!="GRanges" || length(gr)!=1){
            stop("gr must be an object of GRanges with one element.")
        }
        chromosome <- as.character(GenomicRanges::seqnames(gr))[1]
        start <- GenomicRanges::start(gr)[1]
        end <- GenomicRanges::end(gr)[1]
        strand <- as.character(GenomicRanges::strand(gr))[1]
    }
    if(ignore.strand) strand <- "*"
    if(end < start) stop("end should be greater than start.")
    
    if(class(viewerStyle)!="trackViewerStyle"){
        stop("viewerStyle must be an object of 'trackViewerStyle'.")
    }
    if(!is.logical(newpage)) stop("newpage should be a logical vector.")
    
    trackList <- filterTracks(trackList, chromosome, start, end, strand)
    
    if(!is.null(operator)){
        ##change dat as operator(dat, dat2)
        ##dat2 no change
        trackList <- lapply(trackList, function(.ele){
            if(.ele@type=="data" && 
                   length(.ele@dat2)>0 &&
                   length(.ele@dat)>0){
                .ele@dat <- GRoperator(.ele@dat, 
                                       .ele@dat2, 
                                       col="score", 
                                       operator=operator)
                if(operator!="+") .ele@dat2 <- GRanges()
            }
            .ele
        })
    }
    
    if(newpage) grid.newpage()
    
    if(autoOptimizeStyle){
        opt <- optimizeStyle(trackList, viewerStyle)
        trackList <- opt$tracks
        viewerStyle <- opt$style
    }
    
    margin <- viewerStyle@margin
    
    ##xscale, yscale
    xscale <- c(start, end)
    
    yscales <- getYlim(trackList, operator)
    yHeights <- getYheight(trackList)
    
    pushViewport(viewport(x=margin[2], y=margin[1], width=1-margin[2]-margin[4],
                          height=1-margin[1]-margin[3], just=c(0,0)))
    if(viewerStyle@xaxis){##draw x axis in bottom
        drawXaxis(xscale, viewerStyle)
    }
    popViewport()
    
    pushViewport(viewport(x=0, y=margin[1], width=1,
                          height=1-margin[1]-margin[3], just=c(0,0)))
    total <- length(trackList)
#    if(interactive()) pb <- txtProgressBar(min=0, max=total, style=3)
    ht <- 0
    for(i in 1:total){
        plotTrack(names(trackList)[i], trackList[[i]], 
                  viewerStyle, ht,
                  yscales[[i]], yHeights[i], xscale,
                  chromosome, strand, operator)
        ht <- ht + yHeights[i]
#        if(interactive()) setTxtProgressBar(pb, i)
    }
#    if(interactive()) close(pb)
    popViewport()
    
    if(viewerStyle@flip) xscale <- rev(xscale)
    return(invisible(viewport(x=margin[2], y=margin[1], 
                              height=1 - margin[1]- margin[3], 
                              width=1 -margin[2] - margin[4],
                              just=c(0,0), xscale=xscale, yscale=c(0,1))))
}
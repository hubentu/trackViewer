convertFont <- function(){
        return(36*min(c(convertWidth(unit(1, "snpc"), "inches", valueOnly=TRUE), 
                        convertHeight(unit(1, "snpc"), "inches", valueOnly=TRUE))
                      ))
}
hrScale <- function(r){
    if(any(r<0))
      stop("'r' must be positive")
    if(length(r)!=2)
        stop("'r' must be a vector with two numbers")
    x <- abs(r[2] - r[1])
    suffix <- c("bp", "K", "M", "G")#NOT USE: "T", "P", "E", "Z", "Y"
    base <- 1000L
    n <- length(suffix)
    for(i in 1:n){
        if(x >= base*10){
            if(i < n)
                x <- x/base
        }else break
    }
    x <- round(x=x/10, digits=0)
    if(i==1) x <- 10^round(log10(x), digits=0) / 2
    return(list(scale=x, unit=suffix[i], range=r))
}

locateScale <- function(x, y, maxY, scale){
    if(length(x)==0) return(c(start=NA, end=NA))
    suffix <- c(1, 1000, 1000000, 1000000000)
    names(suffix) <- c("bp", "K", "M", "G")
    rg <- scale[[3]]
    scale <- as.numeric(scale[[1]] * suffix[scale[[2]]])
    scale.10 <- round(x=scale/10, digits=1)
    threshold <- maxY/2
    start <- c()
    end <- c()
    START <- TRUE
    y <- y[order(x)]
    x <- x[order(x)]
    for(i in 1:length(x)){
        if(y[i]>threshold){
            if(START){
                START <- FALSE
                start <- c(start, x[i])
            }
        }else{
            if(!START){
                START <- TRUE
                end <- c(end, x[i])
            }
        }
    }
    if(length(start)==length(end)+1) 
        end <- c(end, x[i])
    if(length(start)==0){
        mid <- sum(rg)/2
        return(c(start=mid-scale, end=mid+scale))
    }
    ir <- IRanges(start=c(x[1],start, x[length(x)])-scale.10, 
                  end=c(x[1], end, x[length(x)])+scale.10)
    ir <- gaps(ir)
    if(length(ir)==0) return(c(start=NA, end=NA))
    ir <- ir[order(width(ir), decreasing=TRUE)]
    mid <- sum(c(start(ir)[1], end(ir)[1]))/2
    return(c(start=mid-scale, end=mid+scale))
}

orderedGR <- function(gr=GRanges()){
    if(length(gr)>0){
        gr[order(as.character(seqnames(gr)), start(gr))]
    }else{
        gr
    }
}

condenceGRs <- function(gr=GRanges(), FUN=sum){
    .gr <- reduce(gr, min.gapwidth=0, with.revmap=TRUE)
    scores <- score(gr)
    .gr$score <- sapply(.gr$revmap, function(.id) FUN(scores[.id]))
    .gr$revmap <- NULL
    .gr
}

disjoinGRs <- function(gr=GRanges(), FUN=sum){
    if(length(gr)<1) return(gr)
    .gr <- disjoin(gr)
    ol <- findOverlaps(.gr, gr, maxgap=0L, minoverlap=1L)
    s <- tapply(score(gr[subjectHits(ol)]), queryHits(ol), FUN=FUN)
    .gr$score <- 0
    .gr$score[as.numeric(names(s))] <- s
    .gr
}

filterTracks <- function(tl, chrom, from, to, st){
    for(i in 1:length(tl)){
        if(tl[[i]]@type=="data"){
            if(tl[[i]]@format=="WIG") {
                tl[[i]] <- parseWIG(tl[[i]], chrom, from, to)
            }
            dat <- tl[[i]]@dat
            dat <- disjoinGRs(dat)
            tl[[i]]@dat <- dat[end(dat)>=from &
                                   start(dat)<=to &
                                   seqnames(dat)==chrom]
            if(length(tl[[i]]@dat2)>0){
                dat2 <- tl[[i]]@dat2
                dat2 <- disjoinGRs(dat2)
                tl[[i]]@dat2 <- dat2[end(dat2)>=from &
                                        start(dat2)<=to &
                                        seqnames(dat2)==chrom]
            }
            if(st %in% c("+", "-")) {
                dat <- tl[[i]]@dat
                tl[[i]]@dat <- dat[strand(dat)==st]
                if(length(tl[[i]]@dat2)>0){
                    dat2 <- tl[[i]]@dat2
                    tl[[i]]@dat2 <- dat2[strand(dat2)==st]
                }
            }
        }else{
            dat <- range(tl[[i]]@dat)
            dat <- dat[end(dat)>=from &
                           start(dat)<=to &
                           seqnames(dat)==chrom]
            dat2 <- tl[[i]]@dat2
            if(length(dat2)>0){
                dat2 <- dat2[end(dat2)>=from &
                                 start(dat2)<=to &
                                 seqnames(dat2)==chrom]
            }
            if(length(dat)==0 && length(dat2)==0)
                tl[[i]]@style@height <- 0
        }
    }
    tl
}

getYlim <- function(tl, op){
    yscales <- lapply(tl, function(.ele){
        ylim <- .ele@style@ylim
        if(length(ylim)!=2){
            if(.ele@type=="data"){
                if(length(.ele@dat)>0){
                    ylim <- unique(round(range(.ele@dat$score)))
                }else{
                    ylim <- c(0, 0)
                }
                if(length(.ele@dat2)>0 && is.null(op)){
                    ylim2 <- unique(round(range(.ele@dat2$score)))
                    ylim <- c(ylim, -1*ylim2)
                }
                ylim <- range(c(0, ylim))
            }else{
                ylim <- c(0, 0)
            }            
        }
        ylim
    })
    
    yscaleR <- range(unlist(yscales))
    if(diff(yscaleR)==0) yscaleR <- c(0, 1)
    yscales <- lapply(yscales, function(.ele){
        if(diff(.ele)==0){
            if(all(.ele>=0)){
                .ele <- c(0, yscaleR[2])
            }else{
                .ele <- c(yscaleR[1], 0)
            }
        }
        if(.ele[1]>0) .ele[1] <- 0
        .ele
    })
    names(yscales) <- names(tl)
    yscales
}

getYheight <- function(tl){
    yHeights <- sapply(tl, function(.ele){
        yh <- .ele@style@height
        if(length(yh)==0) yh <- -1
        yh[1]
    })
    noY <- yHeights == -1
    yHeightsT <- sum(yHeights[!noY])
    if(yHeightsT>1)
        stop("total heights of data tracks is greater than 1.")
    if(length(yHeights[noY]) > 0){
        yHeights[noY] <- 
            (1 - yHeightsT) / length(yHeights[noY])
    }
    names(yHeights) <- names(tl)
    yHeights
}

drawXaxis <- function(xscale, style){
    scale <- hrScale(xscale)
    suffix <- c(1, 1000, 1000000, 1000000000)
    names(suffix) <- c("bp", "K", "M", "G")
    interval <- scale$scale * suffix[scale$unit]
    start <- ceiling(xscale[1]/interval)
    end <- floor(xscale[2]/interval)
    label <- interval * start:end
    if(style@flip) xscale <- rev(xscale)
    at <- rescale(label, from=xscale)
    gp <- style@xgp
    class(gp) <- "gpar"
    rot <- ifelse(style@xlas %in% c(0, 1), 0, 90)
    grid.xaxis(at=at, label=label, gp=gp,
               edits = gEdit(gPath="labels", rot=rot),
               draw=style@xaxis)
}
putGeneYlab <- function(curViewStyle, style, name, height, xscale, rang){
    gap <- (xscale[2] - xscale[1])/100
    just <- style@ylabpos=="upstream"
    strand <- as.character(strand(rang))
    if(curViewStyle@flip){
        if(strand=="+"){
            x <- ifelse(just, start(rang) + gap, end(rang) - gap)
            just <- ifelse(just, "left", "right")
        }else{
            x <- ifelse(just, end(rang) - gap, start(rang) + gap)
            just <- ifelse(just, "right", "left")
        }
    }else{
        if(strand=="+"){
            x <- ifelse(just, start(rang) - gap, end(rang) + gap)
            just <- ifelse(just, "right", "left")
        }else{
            x <- ifelse(just, end(rang) + gap, start(rang) - gap)
            just <- ifelse(just, "left", "right")
        }
    }
    
    gp <- style@ylabgp
    class(gp) <- "gpar"
    if(is.null(gp$cex)) gp$cex <- optFontSize("z", curViewStyle, 
                                              height=height)
    pushViewport(viewport(x=curViewStyle@margin[2], y=0, 
                          height=1, 
                          width=1-curViewStyle@margin[2]-curViewStyle@margin[4], 
                          clip="off",
                          just=c(0,0), 
                          xscale=xscale))
    grid.text(x=x, y=.5, label=name, rot=0, just=just, gp=gp, 
              default.units="native")
    popViewport()
}

putYlab <- function(curViewStyle, style, name, yHeightBottom, yHeightTop, height){
    ##c("left", "right", "topleft", "bottomleft", "topright", "bottomright")
    vp <- switch(style@ylabpos,
                 left=viewport(x=curViewStyle@margin[2]*.4, 
                               width=curViewStyle@margin[2]*.8,
                               just="center"),
                 right=viewport(x=1 - curViewStyle@margin[4]*.6, 
                                width=curViewStyle@margin[4]*.8,
                                just="center"),
                 topleft=viewport(y=1-yHeightTop, height=yHeightTop, just="bottom"),
                 bottomleft=viewport(y=0, height=yHeightBottom, just="bottom"),
                 topright=viewport(y=1-yHeightTop, height=yHeightTop, just="bottom"),
                 bottomright=viewport(y=0, height=yHeightBottom, just="bottom"),
                 viewport(x=curViewStyle@margin[2]*.4, 
                          width=curViewStyle@margin[2]*.8))
    just <- switch(style@ylabpos,
                   left="center",
                   right="center",
                   topleft=c(0, 0),
                   topright=c(1, 0),
                   bottomleft=c(0, 1),
                   bottomright=c(1, 1),
                   "center"
        )
    x <- switch(style@ylabpos,
                left=.5,
                right=.5,
                topleft=curViewStyle@margin[2],
                topright=1-curViewStyle@margin[4],
                bottomleft=curViewStyle@margin[2],
                bottomright=1-curViewStyle@margin[4],
                .5
        )
    y <- switch(style@ylabpos,
                left=.5,
                right=.5,
                topleft=.1,
                topright=.1,
                bottomleft=.9,
                bottomright=.9,
                .5
        )
    pushViewport(vp)
    rot <- ifelse(style@ylablas %in% c(0, 3), 90, 0)
    gp <- style@ylabgp
    class(gp) <- "gpar"
    if(style@ylabpos %in% c("topleft", "topright", "bottomleft", "bottomright")){
        rot <- 0
        curHeight <- ifelse(grepl("top",style@ylabpos), yHeightTop, yHeightBottom)
        if(is.null(gp$cex)) gp$cex <- optFontSize("z", curViewStyle, 
                                                  height=curHeight)
    }else{
        if(curViewStyle@autolas){
            curWidth <- ifelse(style@ylabpos=="left", 
                               curViewStyle@margin[2],
                               curViewStyle@margin[4])
            rot <- ifelse(convertHeight(unit(height, "npc"), 
                                        unitTo="inches", valueOnly=TRUE)
                          > convertWidth(unit(curWidth, "npc"), 
                                         unitTo="inches", valueOnly=TRUE),
                          90, 0)
            if(is.null(gp$cex)) gp$cex <- optFontSize("z", curViewStyle, 
                                                      height=height)
        }
    }
    grid.text(x=x, y=y, label=name, rot=rot, just=just, gp=gp)
    popViewport()
}

drawYaxis <- function(ylim, yaxisStyle, curViewStyle){
    if(yaxisStyle@main){
        vp <- viewport(x=curViewStyle@margin[2] * .2, 
                       width=curViewStyle@margin[2] *.4,
                       y=0, height=1, clip="off",
                       just=c(0,0), yscale=ylim)
    }else{
        vp <- viewport(x=curViewStyle@margin[2], 
                       width=1 - curViewStyle@margin[2] - curViewStyle@margin[4],
                       y=0, height=1, clip="off", just=c(0,0), yscale=ylim)
    }
    pushViewport(vp)
    at <- unique(c(0,ylim))
    at <- at[order(at)]
    label <- yaxisStyle@label
    if(label){
        label <- at
    }
    gp <- yaxisStyle@gp
    class(gp) <- "gpar"
    grid.yaxis(at=at, label=label, main=FALSE, gp=gp,
               draw=yaxisStyle@draw)
    popViewport()
}

drawXscale <- function(scale){
    gp <- scale@gp
    class(gp) <- "gpar"
    grid.segments(x0=scale@from@x, 
                  y0=scale@from@y,
                  x1=scale@to@x,
                  y1=scale@to@y,
                  default.units=scale@from@unit,
                  gp=gp)
    grid.segments(x0=scale@from@x,
                  y0=scale@from@y,
                  x1=scale@from@x,
                  y1=scale@from@y * 1.05,
                  default.units=scale@from@unit,
                  gp=gp)
    grid.segments(x0=scale@to@x,
                  y0=scale@to@y,
                  x1=scale@to@x,
                  y1=scale@to@y * 1.05,
                  default.units=scale@to@unit,
                  gp=gp)
    grid.text(label=scale@label, 
              x=(scale@from@x + scale@to@x)/2,
              y=(scale@from@y + scale@to@y)/2*1.025,
              gp=gp,
              just="bottom",
              default.units=scale@from@unit)
}
function getVideoTag() {
    const videos = document.getElementsByTagName('video')
    return videos.item(0)
}

function updateVideoTagWithSrc(src) {
    const videoTag = getVideoTag()
    videoTag.src = src
}

function playVideo() {
    const videoTag = getVideoTag()
    videoTag.play();
}

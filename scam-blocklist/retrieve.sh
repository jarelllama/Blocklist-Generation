#!/bin/bash

cleanup() {
    find . -maxdepth 1 -type f -name "*.tmp" -delete
}

trap cleanup exit

retrieveDomains() {
    # TODO: output all pages
    curl 'https://customsearch.googleapis.com/customsearch/v1?cx=427244e9065f64c3f&exactTerms=We%20have%20spent%20our%20entire%20lives%20in%20the%20business%20of%20clothing%2C%20from%20economy%20lines%20to%20luxury%20lines%2C.Thousands%20of%20products%20in%20different%20styles%20are%20waiting%20for%20you!After%20spending%2015%20years%20learning%20this%20market%20and%20business%20we%20decided%20to%20put%20all%20of%20our%20contacts%20in%20manufacturing%20and%20designing%20to%20good%20use.%20Our%20mission%20is%20to%20bring%20the%20newest%20and%20best%20designs%20in%20clothing%20to%20you.&filter=0&key=
}


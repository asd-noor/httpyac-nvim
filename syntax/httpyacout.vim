if exists("b:current_syntax") | finish | endif

runtime! syntax/json.vim
if exists("b:current_syntax")
  unlet b:current_syntax
endif

syn match   httpyacoutComment "\v^#.*$"
syn keyword httpyacoutMethod OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT nextgroup=httpyacoutPath
syn match   httpyacoutPath  /.*$/hs=s+1 contained

syn match httpyacoutField /^\(\w\)[^:]\+:/he=e-1
syn match httpyacoutDateField /^[Dd]ate:/he=e-1    nextgroup=httpyacoutDate
syn match httpyacoutDateField /^[Ee]xpires:/he=e-1 nextgroup=httpyacoutDate
syn match httpyacoutDate /.*$/ contained

syn region httpyacoutHeader start=+^HTTP/+ end=+ + nextgroup=httpyacout200,httpyacout300,httpyacout400,httpyacout500
syn match  httpyacout200 /2\d\d/ nextgroup=httpyacoutStatus contained
syn match  httpyacout300 /3\d\d/ nextgroup=httpyacoutstatus contained
syn match  httpyacout400 /4\d\d/ nextgroup=httpyacoutstatus contained
syn match  httpyacout500 /5\d\d/ nextgroup=httpyacoutstatus contained

syn match  httpyacoutStatus /.*$/ contained

syn region httpyacoutString start=/\vr?"/ end=/\v"/
syn match  httpyacoutNumber /\v[ =]@1<=[0-9]*.?[0-9]+[ ,;&\n]/he=e-1

hi link httpyacoutComment   @comment
hi link httpyacoutMethod    @type
hi link httpyacoutPath      @text.uri
hi link httpyacoutField     @constant
hi link httpyacoutDateField @constant
hi link httpyacoutDate      @attribute
hi link httpyacoutString    @string
hi link httpyacoutNumber    @number
hi link httpyacoutHeader    @constant
hi link httpyacout200       Msg
hi link httpyacout300       MoreMsg
hi link httpyacout400       WarningMsg
hi link httpyacout500       ErrorMsg

let b:current_syntax = "httpyacout"

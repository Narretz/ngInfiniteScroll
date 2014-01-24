mod = angular.module('infinite-scroll', [])

mod.value('THROTTLE_MILLISECONDS', null)

mod.directive 'infiniteScroll', ['$rootScope', '$window', '$timeout', 'THROTTLE_MILLISECONDS', \
                                    ($rootScope, $window, $timeout, THROTTLE_MILLISECONDS) ->
  link: (scope, elem, attrs) ->
    $window = angular.element($window)

    # infinite-scroll-distance specifies how close to the bottom of the page
    # the window is allowed to be before we trigger a new scroll. The value
    # provided is multiplied by the window height; for example, to load
    # more when the bottom of the page is less than 3 window heights away,
    # specify a value of 3. Defaults to 0.
    scrollDistance = 0
    if attrs.infiniteScrollDistance?
      scope.$watch attrs.infiniteScrollDistance, (value) ->
        scrollDistance = parseInt(value, 10)

    # infinite-scroll-disabled specifies a boolean that will keep the
    # infnite scroll function from being called; this is useful for
    # debouncing or throttling the function call. If an infinite
    # scroll is triggered but this value evaluates to true, then
    # once it switches back to false the infinite scroll function
    # will be triggered again.
    scrollEnabled = true
    checkWhenEnabled = false
    if attrs.infiniteScrollDisabled?
      scope.$watch attrs.infiniteScrollDisabled, (value) ->
        scrollEnabled = !value
        if scrollEnabled && checkWhenEnabled
          checkWhenEnabled = false
          handler()

    container = null
    error = new Error("invalid infinite-scroll-container attribute.")

    # infinite-scroll-container sets the container which we want to be
    # infinte scrolled, instead of the whole window window. Must be an
    # Angular or jQuery element.
    if attrs.infiniteScrollContainer?
      attrs.$observe 'infiniteScrollContainer', (newVal) ->
        if newVal == 'window'
          newVal = $window
        else
          newVal = angular.element(newVal)

        if newVal.length > 0
          if newVal != container
            bind(newVal, true)
          container = newVal
        else
          throw error
    # infinite-scroll-parent establishes this element's parent as the
    # container infinitely scrolled instead of the whole window.
    else if attrs.infiniteScrollParent?
      container = elem.parent()
      scope.$watch attrs.infiniteScrollParent, () ->
        parent = elem.parent()
        if container != parent
          bind(parent, true)
          container = parent
    else
      bind($window)

    # infinite-scroll specifies a function to call when the window,
    # or some other container specified by infinite-scroll-container,
    # is scrolled within a certain range from the bottom of the
    # document. It is recommended to use infinite-scroll-disabled
    # with a boolean that is set to true when the function is
    # called in order to throttle the function call.
    handler = ->
      if container == $window
        containerBottom = container.height() + container.scrollTop()
        elementBottom = elem.offset().top + elem.height()
      else
        containerBottom = container.height()
        elementBottom = elem.offset().top - container.offset().top + elem.height()
      remaining = elementBottom - containerBottom
      shouldScroll = remaining <= container.height() * scrollDistance

      if shouldScroll && scrollEnabled
        if $rootScope.$$phase
          scope.$eval attrs.infiniteScroll
        else
          scope.$apply attrs.infiniteScroll
      else if shouldScroll
        checkWhenEnabled = true

    # The optional THROTTLE_MILLISECONDS configuration value specifies
    # a minimum time that should elapse between each call to the
    # handler. N.b. the first call the handler will be run
    # immediately, and the final call will always result in the
    # handler being called after the `wait` period elapses.
    # A slimmed down version of underscore's implementation.
    throttle = (func, wait) ->
      timeout = null
      previous = 0
      later = ->
        previous = new Date().getTime()
        $timeout.cancel(timeout)
        timeout = null
        func.call()
        context = null

      return ->
        now = new Date().getTime()
        remaining = wait - (now - previous)
        if remaining <= 0
          clearTimeout timeout
          $timeout.cancel(timeout)
          timeout = null
          previous = now
          func.call()
        else timeout = $timeout(later, remaining) unless timeout

    if THROTTLE_MILLISECONDS?
      handler = throttle(handler, THROTTLE_MILLISECONDS)

    bind = (newContainer, unbind) ->
      if unbind == true && container?
        container.off 'scroll', handler

      newContainer.on 'scroll', handler
      scope.$on '$destroy', ->
        newContainer.off 'scroll', handler

    $timeout (->
      if attrs.infiniteScrollImmediateCheck
        if scope.$eval(attrs.infiniteScrollImmediateCheck)
          handler()
      else
        handler()
    ), 0
]

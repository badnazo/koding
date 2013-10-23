jraphical = require 'jraphical'
module.exports = class JPaymentPlan extends jraphical.Module

  force =
    forceRefresh  : yes
    forceInterval : 60

  recurly   = require 'koding-payment'

  {secure, dash}       = require 'bongo'
  {difference, extend} = require 'underscore'

  JUser                = require '../user'
  JPayment             = require './index'
  JPaymentToken        = require './token'
  JPaymentSubscription = require './subscription'

  @share()

  @set
    indexes:
      code         : 'unique'
    sharedMethods  :
      static       : ['fetchPlans', 'fetchPlanByCode', 'fetchAccountDetails']
      instance     : ['getToken', 'getType', 'subscribe', 'getSubscriptions']
    schema         :
      code         : String
      title        : String
      description  : Object
      feeMonthly   : Number
      feeInitial   : Number
      feeInterval  : Number
      product      :
        prefix     : String
        category   : String
        item       : String
        version    : Number
      lastUpdate   : Number

  @fetchAccountDetails = secure ({connection:{delegate}}, callback) ->
    console.error 'needs to be reimplemented'
#    recurly.fetchAccountDetailsByPaymentMethodId (JPayment.userCodeOf delegate), callback

  @fetchPlans = secure (client, options, callback) ->
    console.log 'FETCH PLANS'

    selector = (Object.keys options)
      .reduce( (acc, key) ->
        acc["product.#{key}"] = options[key]
        acc
      , {})

    JPayment.invalidateCacheAndLoad this, selector, force, callback

  @fetchPlanByCode = (code, callback) -> @one { code }, callback

  getToken: secure (client, data, callback) ->
    JPaymentToken.createToken client, planCode: @code, callback

  subscribe: (paymentMethodId, data, callback) ->
    data.multiple ?= no

    JPaymentSubscription.fetchAllSubscriptions {
      paymentMethodId
      planCode  : @code
      $or       : [
        {status : 'active'}
        {status : 'canceled'}
      ]
    }, (err, [sub]) =>
      return callback err  if err

      if sub
        return callback 'Already subscribed.'  unless data.multiple

        quantity = (sub.quantity ? 1) + 1

        recurly.updateSubscription paymentMethodId,
          quantity : quantity
          plan     : @code
          uuid     : sub.uuid
        , (err) =>
          return callback err  if err
          sub.update $set: { quantity }, (err)->
            if err
            then callback err
            else callback null, sub
      else
        recurly.createSubscription paymentMethodId, plan: @code, (err, result) ->
          return callback err  if err
          console.log { err, result }
          # { planCode, uuid, quantity, status, datetime, expires, renew, amount } = result
          # sub = new JPaymentSubscription {
          #   userCode, planCode, uuid, quantity, status, datetime, expires, renew, amount
          # }
          # sub.save (err)-> callback err, sub

  subscribe$: secure ({connection:{delegate}}, paymentMethodId, data, callback) ->
    @subscribe paymentMethodId, data, callback

  # subscribeGroup: (group, data, callback)->
  #   doSubscribe "group_#{group._id}", data, callback

  fetchSubscription: secure ({ connection:{ delegate }}, callback) ->
    selector    =
      userCode  : "user_#{delegate.getId()}"
      planCode  : @code

    JPaymentSubscription.one selector, callback

  getType:-> if @feeInterval is 1 then 'recurring' else 'single'

  fetchSubscriptions: (callback) ->
    JPaymentSubscription.all
      planCode: @code
      $or: [
        { status: 'active' }
        { status: 'canceled' }
      ]
    , callback

  fetchOwnerGroup: (callback) ->
    if @product.prefix isnt 'groupplan'
      callback null, 'koding'
    else
      JGroup = require '../group'
      JGroup.one _id: @product.category, (err, group)->
        callback err, unless err then group.slug

  @updateCache = (selector, callback)->
    # TODO: what on earth is the point of this? C
    JPayment.updateCache(
      constructor : this
      method      : 'fetchPlans'
      keyField    : 'code'
      message     : 'product cache'
      forEach     : (k, cached, plan, fin)->
        return fin()  unless k.match /^([a-zA-Z0-9-]+_){3}[0-9]+$/

        {title, desc, feeMonthly, feeInitial, feeInterval} = plan

        [prefix, category, item, version] = k.split '_'

        version++

        description = (try JSON.parse desc)

        cached.set {
          title
          description
          feeMonthly
          feeInitial
          feeInterval
          lastUpdate: Date.now()
          product: {
            prefix
            category
            item
            version
          }
        }

        cached.save fin

    , callback)

$(document).ready(function(){
  $('#tabs').tabs()
  
  $('#taxon_range_map').taxonMap()
  window.map = $('#taxon_range_map').data('taxonMap')
  $('#tabs').bind('tabsshow', function(event, ui) {
    if (ui.panel.id == "taxon_range") {
      google.maps.event.trigger(window.map, 'resize')
      $('#taxon_range_map').taxonMap('fit')
    }
  })
  
  $('.list_selector_row .addlink')
    .bind('ajax:beforeSend', function() {
      $(this).hide()
      $(this).nextAll('.loading').show()
    })
    .bind('ajax:complete', function() {
      $(this).nextAll('.loading').hide()
    })
    .bind('ajax:success', function() {
      $(this).siblings('.removelink').show()
      $(this).parents('.list_selector_row').addClass('added')
    })
    .bind('ajax:error', function(event, jqXHR, ajaxSettings, thrownError) {
      $(this).show()
      var json = eval('(' + jqXHR.responseText + ')')
      var errorStr = 'Heads up: ' + json.errors
      alert(errorStr)
    })
    
  $('.list_selector_row .removelink')
    .bind('ajax:beforeSend', function() {
      $(this).hide()
      $(this).nextAll('.loading').show()
    })
    .bind('ajax:complete', function() {
      $(this).nextAll('.loading').hide()
    })
    .bind('ajax:success', function() {
      $(this).siblings('.addlink').show()
      $(this).parents('.list_selector_row').removeClass('added')
    })
    .bind('ajax:error', function(event, jqXHR, ajaxSettings, thrownError) {
      $(this).show()
    })

  if (TAXON.auto_description) {
    getDescription('/taxa/'+TAXON.id+'/description')
  }

  // Set up photo modal dialog
  $('#edit_photos_dialog').dialog({
    modal: true, 
    title: 'Choose photos for this taxon',
    autoOpen: false,
    width: 700,
    open: function( event, ui ) {
      $('#edit_photos_dialog').loadingShades('Loading...', {cssClass: 'smallloading'})
      $('#edit_photos_dialog').load('/taxa/'+TAXON.id+'/edit_photos', function() {
        var photoSelectorOptions = {
          defaultQuery: TAXON.name,
          urlParams: {
            authenticity_token: $('meta[name=csrf-token]').attr('content'),
            limit: 14
          },
          afterQueryPhotos: function(q, wrapper, options) {
            $(wrapper).imagesLoaded(function() {
              $('#edit_photos_dialog').centerDialog()
            })
          }
        }
        $('.tabs', this).tabs({
          show: function(event, ui) {
            if ($(ui.panel).attr('id') == 'flickr_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(photoSelectorOptions)
            } else if ($(ui.panel).attr('id') == 'inat_obs_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(
                $.extend(true, {}, photoSelectorOptions, {baseURL: '/taxa/'+TAXON.id+'/observation_photos'})
              )
            } else if ($(ui.panel).attr('id') == 'eol_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(
                $.extend(true, {}, photoSelectorOptions, {baseURL: '/eol/photo_fields'})
              )
            } else if ($(ui.panel).attr('id') == 'wikimedia_taxon_photos' && !$(ui.panel).hasClass('loaded')) {
              $('.taxon_photos', ui.panel).photoSelector(
                $.extend(true, {}, photoSelectorOptions, {taxon_id: TAXON.id, baseURL: '/wikimedia_commons/photo_fields'})
              )
            }
            $(ui.panel).addClass('loaded')
            $('#edit_photos_dialog').centerDialog()
          }
        })
      })
    }
  })
})

function getDescription(url) {
  $.ajax({
    url: url,
    method: 'get',
    beforeSend: function() {
      $('.taxon_description').loadingShades()
    },
    success: function(data, status) {
      $('.taxon_description').replaceWith(data);
      $('.taxon_description select').change(function() {
        getDescription('/taxa/'+TAXON.id+'/description?from='+$(this).val())
      })
    },
    error: function(request, status, error) {
      $('.taxon_description').loadingShades('close')
    }
  })
}

# Create a JSON service account key here:
#
# https://console.cloud.google.com/apis/credentials/serviceaccountkey
#
# then run with
#
#   GOOGLE_APPLICATION_CREDENTIALS=<file>.json IMG=... ruby google.rb
#
# http://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/VisionV1/VisionService

require 'googleauth'
require 'google/apis/vision_v1'
require 'rmagick'
require 'byebug'

class FaceDetection
  Vision = Google::Apis::VisionV1

  Emotions = {
    joy_likelihood: "joy",
    surprise_likelihood: "open_mouth",
    anger_likelihood: "angry",
    sorrow_likelihood: "weary"
  }

 def initialize(image_path, output_path)
   @path = image_path
   @output_path = output_path
   init_google
 end

 def process_image
   draw_faces
 end

 def detect
   google_vision_face_detect
 end

 def draw_faces
   @face_annotations ||= detect
   img = Magick::Image.read(@path)[0]
   gc = Magick::Draw.new

   if @face_annotations && !@face_annotations.empty?
     @face_annotations.each do |face|
       points = reverse_and_flatten_face_annotations(face)
       gc.stroke('red')
       gc.stroke_width(4)
       gc.fill_opacity('0%')
       gc.polygon(*points)
       gc.draw(img)
     end

     img.write(@output_path)

     return true
   end

   return false
 end

 def find_emotions
   @face_annotations ||= detect
   emotion_emojis = []

   if @face_annotations && !@face_annotations.empty?
     @face_annotations.each do |face|
       p face
       Emotions.each do |emotion|
         if ["POSSIBLE", "LIKELY", "VERY_LIKELY"].include? face.send(emotion[0])
           emotion_emojis << emotion[1]
         end
       end
     end
   end

   emotion_emojis
 end

 def emotions
   @emotions ||= find_emotions
 end

 private
 def init_google
   @service = Vision::VisionService.new

   scopes = ['https://www.googleapis.com/auth/cloud-platform']
   authorization = Google::Auth.get_application_default(scopes)
   @service.authorization = authorization
 end

 def google_vision_face_detect
   content = File.read(@path)
   image = Vision::Image.new(content: content)
   feature = Vision::Feature.new(type: 'FACE_DETECTION')
   req = Vision::BatchAnnotateImagesRequest.new(
     requests: [{
       image: image,
       features: [feature]
     }]
   )

   # https://cloud.google.com/prediction/docs/reference/v1.6/performance#partial
   res = @service.annotate_image(req, fields: 'responses(faceAnnotations)')

   return res.responses.first.face_annotations
 end

 def reverse_and_flatten_face_annotations(face_hash)
   arr = face_hash.fd_bounding_poly.to_h[:vertices].map{|v| v.values}
   arr.map{ |pair| pair.reverse }.flatten
 end

end



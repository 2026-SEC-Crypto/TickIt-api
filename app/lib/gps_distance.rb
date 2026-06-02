# frozen_string_literal: true

module TickIt
  # Haversine formula: great-circle distance between two GPS coordinates.
  module GpsDistance
    EARTH_RADIUS_METERS = 6_371_000
    MAX_ATTENDANCE_METERS = 50

    # Returns distance in metres between two lat/lng pairs.
    def self.meters(lat1, lng1, lat2, lng2)
      φ1 = lat1 * Math::PI / 180
      φ2 = lat2 * Math::PI / 180
      Δφ = (lat2 - lat1) * Math::PI / 180
      Δλ = (lng2 - lng1) * Math::PI / 180

      a = Math.sin(Δφ / 2)**2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2)**2
      EARTH_RADIUS_METERS * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end

    def self.within_range?(lat1, lng1, lat2, lng2, max_meters: MAX_ATTENDANCE_METERS)
      meters(lat1, lng1, lat2, lng2) <= max_meters
    end
  end
end

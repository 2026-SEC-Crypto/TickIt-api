# frozen_string_literal: true

module TickIt
  class Api < Roda
    route('applications') do |r|
      r.is do
        r.get do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          unless TickIt::TeacherApplicationPolicy.new(account, nil, scope: scope_from_token).view_all?
            response.status = 403
            next({ error: 'Forbidden: admin only' }.to_json)
          end

          { applications: TickIt::TeacherApplicationService.all_applications }.to_json
        end

        r.post do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          unless TickIt::TeacherApplicationPolicy.new(account, nil, scope: scope_from_token).can_create?
            response.status = 403
            next({ error: 'Forbidden: only regular users can apply' }.to_json)
          end

          application = TickIt::TeacherApplicationService.apply(account)
          response.status = 201
          { message: 'Application submitted', application: application.api_hash }.to_json
        rescue ArgumentError => e
          response.status = 409
          { error: e.message }.to_json
        end
      end

      r.on String do |id|
        application = TickIt::TeacherApplicationService.find(id)

        r.patch 'approve' do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          if application.nil? || !TickIt::TeacherApplicationPolicy.new(account, application, scope: scope_from_token).can_approve?
            response.status = 404
            next({ error: 'Application not found' }.to_json)
          end

          TickIt::TeacherApplicationService.approve(application)
          { message: 'Application approved', application: application.api_hash }.to_json
        rescue ArgumentError => e
          response.status = 409
          { error: e.message }.to_json
        end

        r.patch 'reject' do
          account = account_from_token
          if account.nil?
            response.status = 401
            next({ error: 'Unauthorized: valid Bearer token required' }.to_json)
          end

          if application.nil? || !TickIt::TeacherApplicationPolicy.new(account, application, scope: scope_from_token).can_reject?
            response.status = 404
            next({ error: 'Application not found' }.to_json)
          end

          TickIt::TeacherApplicationService.reject(application)
          { message: 'Application rejected', application: application.api_hash }.to_json
        rescue ArgumentError => e
          response.status = 409
          { error: e.message }.to_json
        end
      end
    end
  end
end

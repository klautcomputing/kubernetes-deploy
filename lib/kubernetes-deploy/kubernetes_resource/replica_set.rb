# frozen_string_literal: true
require 'kubernetes-deploy/kubernetes_resource/base_set'
module KubernetesDeploy
  class ReplicaSet < BaseSet
    TIMEOUT = 5.minutes
    attr_reader :desired_replicas

    def initialize(namespace:, context:, definition:, logger:, parent: nil, deploy_started: nil)
      @parent = parent
      @deploy_started = deploy_started
      @rollout_data = { "replicas" => 0 }
      @pods = []
      super(namespace: namespace, context: context, definition: definition, logger: logger)
    end

    def sync(rs_data = nil)
      if rs_data.blank?
        raw_json, _err, st = kubectl.run("get", type, @name, "--output=json")
        rs_data = JSON.parse(raw_json) if st.success?
      end

      if rs_data.present?
        @found = true
        @desired_replicas = rs_data["spec"]["replicas"].to_i
        @rollout_data = { "replicas" => 0 }.merge(rs_data["status"]
          .slice("replicas", "availableReplicas", "readyReplicas"))
        @status = @rollout_data.map { |state_replicas, num| "#{num} #{state_replicas.chop.pluralize(num)}" }.join(", ")
        @pods = find_pods(rs_data)
      else # reset
        @found = false
        @rollout_data = { "replicas" => 0 }
        @status = nil
        @pods = []
      end
    end

    def deploy_succeeded?
      @desired_replicas == @rollout_data["availableReplicas"].to_i &&
      @desired_replicas == @rollout_data["readyReplicas"].to_i
    end

    private

    def unmanaged?
      @parent.blank?
    end
  end
end

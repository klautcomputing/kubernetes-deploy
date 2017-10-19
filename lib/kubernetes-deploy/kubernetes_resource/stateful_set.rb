# frozen_string_literal: true
require 'kubernetes-deploy/kubernetes_resource/base_set'
module KubernetesDeploy
  class StatefulSet < BaseSet
    TIMEOUT = 5.minutes

    def sync
      raw_json, _err, st = kubectl.run("get", type, @name, "--output=json")
      @found = st.success?

      if @found
        stateful_data = JSON.parse(raw_json)
        @current_generation = stateful_data["metadata"]["generation"]
        @observed_generation = stateful_data["status"]["observedGeneration"]
        @desired_replicas = stateful_data["spec"]["replicas"].to_i
        @rollout_data = stateful_data["status"].slice("replicas")
        @status = @rollout_data.map { |state_replicas, num| "#{num} #{state_replicas.chop.pluralize(num)}" }.join(", ")
        @pods = find_pods(stateful_data)
      else # reset
        @rollout_data = { "replicas" => 0 }
        @status = nil
        @pods = []
      end
    end

    def deploy_succeeded?
      @current_generation == @observed_generation && @desired_replicas == @rollout_data["replicas"].to_i
    end
  end
end

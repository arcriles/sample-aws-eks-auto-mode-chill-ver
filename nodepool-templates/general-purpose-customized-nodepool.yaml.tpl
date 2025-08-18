apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  labels:
    app.kubernetes.io/managed-by: eks
  name: general-purpose-customized
spec:
  weight: 10
  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 720h
    budgets:
    - nodes: "20%"
  template:
    spec:
      expireAfter: 336h
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: eks.amazonaws.com/instance-category
        operator: In
        values:
        - c
        - m
        - r
        - t
      - key: eks.amazonaws.com/instance-generation
        operator: Gt
        values:
        - "4"
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux

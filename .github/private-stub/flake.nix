{
  description = "CI stand-in for the private input";

  # CI cannot fetch the private input, so the workflow substitutes this with
  # --override-input. It has to expose every attribute the configuration reads
  # and carry every path it resolves, not just a store path to interpolate.
  outputs = _: {
    hosts = {
      personal.user = "ci-personal";
      work.user = "ci-work";
    };
  };
}

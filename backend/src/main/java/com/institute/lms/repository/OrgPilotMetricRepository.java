package com.institute.lms.repository;

import com.institute.lms.entity.OrgPilotMetric;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Pilot success measurements, target versus actual. */
@Repository
public interface OrgPilotMetricRepository extends JpaRepository<OrgPilotMetric, Long> {

    List<OrgPilotMetric> findByPilotId(Long pilotId);

    Optional<OrgPilotMetric> findByPilotIdAndMetricKey(Long pilotId, String metricKey);
}

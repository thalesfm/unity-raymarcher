using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : MonoBehaviour
{
    public float speed;

    float m_pitchInput;
    float m_rollInput;
    float m_yawInput;
    Vector3 m_moveInput;

    void OnPitch(InputValue value)
    {
        m_pitchInput = value.Get<float>();
    }

    void OnRoll(InputValue value)
    {
        m_rollInput = value.Get<float>();
    }

    void OnYaw(InputValue value)
    {
        m_yawInput = value.Get<float>();
    }

    void OnHorizontal(InputValue value)
    {
        m_moveInput.x = value.Get<Vector2>().x;
        m_moveInput.z = value.Get<Vector2>().y;
    }

    void OnVertical(InputValue value)
    {
        m_moveInput.y = value.Get<float>();   
    }

    void Update()
    {
        Quaternion deltaRotation = Quaternion.identity;
        deltaRotation *= Quaternion.AngleAxis(0.1f * m_yawInput, transform.up);
        deltaRotation *= Quaternion.AngleAxis(0.1f * -m_pitchInput, transform.right);
        deltaRotation *= Quaternion.AngleAxis(1.0f * -m_rollInput, transform.forward);
        transform.localRotation = deltaRotation * transform.localRotation;

        Vector3 deltaPosition = Vector2.zero;
        deltaPosition += speed * Time.deltaTime * m_moveInput.x * transform.right;
        deltaPosition += 0.5f * speed * Time.deltaTime * m_moveInput.y * transform.up;
        deltaPosition += speed * Time.deltaTime * m_moveInput.z * transform.forward;
        transform.localPosition += deltaPosition;
    }
}
